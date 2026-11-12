// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';
import '../models/transaction_model_adapter.dart';
import '../models/subscription_model.dart';
import '../models/subscription_model_adapter.dart';
import 'secure_storage_service.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService _instance = DatabaseService._();

  factory DatabaseService() => _instance;

  static const String _transactionsBoxName = 'transactions';
  static const String _subscriptionsBoxName = 'subscriptions';
  static const String _settingsBoxName = 'settings';
  static const String _encryptionEnabledKey = 'encryption_enabled';

  /// Encrypted key-value box for the few settings that are themselves
  /// financial data. Opened with the same cipher as the two record boxes, so
  /// it is plain exactly when the user opted out of encryption and encrypted
  /// otherwise. Holds `adjusted_balance`, which used to live in the plain
  /// `settings` box (M-3).
  static const String _vaultSettingsBoxName = 'vault_settings';

  /// The plain-settings key the balance adjustment used to be stored under.
  /// Never renamed: it is read once as a migration source and then blanked.
  static const String _legacyAdjustedBalanceKey = 'adjusted_balance';

  // ---------------------------------------------------------------------------
  // Re-encryption journal (C-1 / H-1)
  //
  // All keys are new and transient. They describe a re-encryption that is in
  // flight, so that a process killed at any point can be rolled back or rolled
  // forward on the next launch by [recoverReencryption]. The salt and the
  // HMAC verifier are not secrets, which is why they may sit in the plain
  // settings box; key material never does.
  // ---------------------------------------------------------------------------
  static const String _journalStateKey = 'reencrypt_state';
  static const String _journalSaltKey = 'reencrypt_pending_salt';
  static const String _journalVerifierKey = 'reencrypt_pending_verifier';
  static const String _journalPathsKey = 'reencrypt_paths';

  /// The new files are being written; the originals are untouched.
  static const String _journalPrepared = 'prepared';

  /// The new files are complete and closed; swap and commit may proceed.
  static const String _journalWritten = 'written';

  /// Suffix of the temporary box each original is re-encrypted into.
  static const String _reencryptSuffix = '_reencrypt';

  late Box<String> _settingsBox;
  late String _homePath;

  bool _initialized = false;
  bool _boxesOpened = false;
  Box<TransactionModel>? _transactionsBox;
  Box<SubscriptionModel>? _subscriptionsBox;
  Box<String>? _vaultSettingsBox;

  bool get isInitialized => _initialized;

  Box<TransactionModel> get transactionsBox {
    final box = _transactionsBox;
    if (box == null) {
      throw StateError(
        'DatabaseService boxes not opened. Call openBoxes() first.',
      );
    }
    return box;
  }

  Box<SubscriptionModel> get subscriptionsBox {
    final box = _subscriptionsBox;
    if (box == null) {
      throw StateError(
        'DatabaseService boxes not opened. Call openBoxes() first.',
      );
    }
    return box;
  }

  Box<String> get vaultSettingsBox {
    final box = _vaultSettingsBox;
    if (box == null) {
      throw StateError(
        'DatabaseService boxes not opened. Call openBoxes() first.',
      );
    }
    return box;
  }

  Box<String> get settingsBox {
    if (!_initialized) {
      throw StateError(
        'DatabaseService not initialized. Call initialize() first.',
      );
    }
    return _settingsBox;
  }

  /// Returns null if not yet decided (first launch),
  /// true if the user chose encryption, false if they opted out.
  ///
  /// Stored as a String because `settingsBox` is a `Box<String>` (mirrors the
  /// existing `has_password` value), so the flag reads cleanly without opening
  /// any encrypted box — it must be known before a cipher is chosen.
  bool? getEncryptionChoice() {
    final val = _settingsBox.get(_encryptionEnabledKey);
    if (val == null) return null;
    return val == 'true';
  }

  Future<void> setEncryptionChoice(bool enabled) async {
    await _settingsBox.put(_encryptionEnabledKey, enabled ? 'true' : 'false');
  }

  /// [path] overrides the Hive home directory. Only tests pass it; the app
  /// always uses the documents directory.
  Future<void> initialize({String? path}) async {
    if (_initialized) return;
    final dir = path ?? (await getApplicationDocumentsDirectory()).path;
    _homePath = dir;
    Hive.init(dir);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SubscriptionModelAdapter());
    }
    _settingsBox = await Hive.openBox<String>(_settingsBoxName);
    _initialized = true;
  }

  /// Whether a re-encryption was interrupted and has not been resolved yet.
  bool get hasPendingReencryption => _settingsBox.get(_journalStateKey) != null;

  Future<void> openBoxes(Uint8List key) async {
    if (_boxesOpened) return;
    // A journal entry here means the process died mid re-encryption and
    // `main()` did not get to recover it. Resolve before touching the files.
    if (hasPendingReencryption) await recoverReencryption();
    // null (never decided) is treated as encrypted: every pre-existing live
    // user has a password and encrypted boxes but no stored choice flag, so the
    // boxes must open WITH a cipher unless the user explicitly opted out.
    final encrypted = getEncryptionChoice() != false;
    final cipher = encrypted ? HiveAesCipher(key) : null;
    await _openDataBoxes(cipher);
    await _migrateAdjustedBalance();
    await _persistRegeneratedSubscriptionIds();
  }

  Future<void> _openDataBoxes(HiveAesCipher? cipher) async {
    final txBox = await Hive.openBox<TransactionModel>(
      _transactionsBoxName,
      encryptionCipher: cipher,
    );
    final subBox = await Hive.openBox<SubscriptionModel>(
      _subscriptionsBoxName,
      encryptionCipher: cipher,
    );
    final vaultBox = await Hive.openBox<String>(
      _vaultSettingsBoxName,
      encryptionCipher: cipher,
    );
    _transactionsBox = txBox;
    _subscriptionsBox = subBox;
    _vaultSettingsBox = vaultBox;
    _boxesOpened = true;
  }

  /// Moves a pre-existing `adjusted_balance` out of the plain settings box
  /// into the encrypted one. Idempotent: a kill between the two writes is
  /// repaired on the next open, and the legacy key is only ever blanked, never
  /// deleted.
  Future<void> _migrateAdjustedBalance() async {
    final legacy = _settingsBox.get(_legacyAdjustedBalanceKey);
    if (legacy == null || legacy.isEmpty) return;
    if (_vaultSettingsBox!.get(_legacyAdjustedBalanceKey) == null) {
      await _vaultSettingsBox!.put(_legacyAdjustedBalanceKey, legacy);
    }
    await _settingsBox.put(_legacyAdjustedBalanceKey, '');
  }

  /// Legacy records predate the `id` field and had none stored, so the adapter
  /// generates a fresh id on first read. Persist that id exactly once so every
  /// later read finds the stored value and stops regenerating (which would
  /// otherwise defeat `cancelNotification` id-based lookups).
  ///
  /// Two legacy records read within the same microsecond would receive the
  /// same generated id (L-8); a regenerated id that collides with any id
  /// already in the box gets a numeric suffix before it is persisted.
  Future<void> _persistRegeneratedSubscriptionIds() async {
    final seen = <String>{
      for (final sub in _subscriptionsBox!.values)
        if (!sub.idWasRegenerated) sub.id,
    };
    for (final sub in _subscriptionsBox!.values) {
      if (sub.idWasRegenerated) {
        var id = sub.id;
        var n = 0;
        while (seen.contains(id)) {
          id = '${sub.id}_${++n}';
        }
        sub.id = id;
        seen.add(id);
        sub.idWasRegenerated = false;
        await sub.save();
      }
    }
  }

  /// Deletes all boxes from disk and resets internal state.
  /// The app closes immediately after (via SystemNavigator.pop()),
  /// so a full re-initialization happens on next launch.
  Future<void> deleteAll() async {
    await _transactionsBox?.deleteFromDisk();
    await _subscriptionsBox?.deleteFromDisk();
    await _vaultSettingsBox?.deleteFromDisk();
    await _settingsBox.deleteFromDisk();

    _transactionsBox = null;
    _subscriptionsBox = null;
    _vaultSettingsBox = null;
    _initialized = false;
    _boxesOpened = false;
  }

  /// Re-encrypts every box under [newKey] and, only once the new files are
  /// safely on disk, commits [newSaltB64] / [newVerifierB64] as the vault's
  /// identity. See [_reEncryptToCipher] for the crash-safety contract.
  ///
  /// [onPhase] is for tests only: it is called with the name of each phase as
  /// it completes, so a test can throw from it to simulate a kill there.
  Future<void> reEncryptBoxes(
    Uint8List oldKey,
    Uint8List newKey, {
    required String newSaltB64,
    required String newVerifierB64,
    void Function(String phase)? onPhase,
  }) =>
      _reEncryptToCipher(
        HiveAesCipher(newKey),
        newSaltB64: newSaltB64,
        newVerifierB64: newVerifierB64,
        onPhase: onPhase,
      );

  /// Enables encryption for an app currently running with unencrypted boxes.
  ///
  /// Same underlying re-encryption as [reEncryptBoxes]; only the entry point
  /// differs because no password existed before, so there is no old key.
  Future<void> enableEncryption(
    Uint8List newKey, {
    required String newSaltB64,
    required String newVerifierB64,
    void Function(String phase)? onPhase,
  }) =>
      _reEncryptToCipher(
        HiveAesCipher(newKey),
        newSaltB64: newSaltB64,
        newVerifierB64: newVerifierB64,
        onPhase: onPhase,
      );

  /// The one re-encryption path, shared by change-password and
  /// enable-encryption.
  ///
  /// Crash-safety contract (C-1 / H-1): the original files are never deleted
  /// or overwritten until a complete, flushed copy under the new cipher exists
  /// on disk, and the vault identity (salt, verifier, routing flags) is never
  /// written until the files it describes are in place. Every step is
  /// recorded in a journal in the plain settings box so that
  /// [recoverReencryption] can finish or undo the work after a kill:
  ///
  ///   1. copy every record into fresh objects in memory;
  ///   2. open `<box>_reencrypt` boxes under the new cipher, record their
  ///      paths plus the pending salt/verifier, state = `prepared`;
  ///   3. write and flush the copies into the temporary boxes, close them,
  ///      state = `written`;
  ///   4. close the originals and rename each temporary file over its
  ///      original (an atomic replace per file);
  ///   5. commit: save salt and verifier, set `encryption_enabled` and
  ///      `has_password`, drop the stale biometric key, clear the journal;
  ///   6. reopen the boxes under the new cipher.
  ///
  /// Killed before 3 completes → recovery deletes the temporaries; the old
  /// identity and files are untouched. Killed at or after `written` →
  /// recovery repeats 4 and 5, both idempotent, until the journal is clear.
  ///
  /// Nothing here runs in a `finally` that changes disk state, so an
  /// exception leaves the disk exactly as a kill at that point would.
  Future<void> _reEncryptToCipher(
    HiveAesCipher newCipher, {
    required String newSaltB64,
    required String newVerifierB64,
    void Function(String phase)? onPhase,
  }) async {
    final txBox = _transactionsBox;
    final subBox = _subscriptionsBox;
    final vaultBox = _vaultSettingsBox;
    if (txBox == null || subBox == null || vaultBox == null) {
      throw StateError('Boxes must be open before re-encryption.');
    }
    if (hasPendingReencryption) {
      throw StateError(
        'A previous re-encryption is still pending. Restart the app.',
      );
    }

    final freshTx = txBox.toMap().map((k, v) => MapEntry(k, _copyTransaction(v)));
    final freshSub =
        subBox.toMap().map((k, v) => MapEntry(k, _copySubscription(v)));
    final freshVault = Map<dynamic, String>.from(vaultBox.toMap());

    // Temporaries left behind by an attempt that died before it wrote its
    // journal entry. They carry a different key, so they must not be reused.
    // They are never open here: the `finally` below closes them on every
    // exit of this method.
    for (final name in const [
      '$_transactionsBoxName$_reencryptSuffix',
      '$_subscriptionsBoxName$_reencryptSuffix',
      '$_vaultSettingsBoxName$_reencryptSuffix',
    ]) {
      if (Hive.isBoxOpen(name)) {
        throw StateError('Temporary box "$name" is unexpectedly open.');
      }
      if (await Hive.boxExists(name)) await Hive.deleteBoxFromDisk(name);
    }

    final tmpTx = await Hive.openBox<TransactionModel>(
      '$_transactionsBoxName$_reencryptSuffix',
      encryptionCipher: newCipher,
    );
    final tmpSub = await Hive.openBox<SubscriptionModel>(
      '$_subscriptionsBoxName$_reencryptSuffix',
      encryptionCipher: newCipher,
    );
    final tmpVault = await Hive.openBox<String>(
      '$_vaultSettingsBoxName$_reencryptSuffix',
      encryptionCipher: newCipher,
    );

    try {
      final paths = {
        _transactionsBoxName: {'from': _pathOf(tmpTx), 'to': _pathOf(txBox)},
        _subscriptionsBoxName: {
          'from': _pathOf(tmpSub),
          'to': _pathOf(subBox),
        },
        _vaultSettingsBoxName: {
          'from': _pathOf(tmpVault),
          'to': _pathOf(vaultBox),
        },
      };
      await _settingsBox.put(_journalSaltKey, newSaltB64);
      await _settingsBox.put(_journalVerifierKey, newVerifierB64);
      await _settingsBox.put(_journalPathsKey, jsonEncode(paths));
      await _settingsBox.put(_journalStateKey, _journalPrepared);
      onPhase?.call(_journalPrepared);

      await tmpTx.putAll(freshTx);
      await tmpTx.flush();
      await tmpSub.putAll(freshSub);
      await tmpSub.flush();
      await tmpVault.putAll(freshVault);
      await tmpVault.flush();
      onPhase?.call('writing');
    } finally {
      // Closing changes nothing on disk; it only releases the in-process
      // handles so a retry in the same session cannot reuse a box that was
      // opened under a different key.
      if (tmpTx.isOpen) await tmpTx.close();
      if (tmpSub.isOpen) await tmpSub.close();
      if (tmpVault.isOpen) await tmpVault.close();
    }

    await _settingsBox.put(_journalStateKey, _journalWritten);
    onPhase?.call(_journalWritten);

    await txBox.close();
    await subBox.close();
    await vaultBox.close();
    _transactionsBox = null;
    _subscriptionsBox = null;
    _vaultSettingsBox = null;
    _boxesOpened = false;

    await _finishReencryption(onPhase: onPhase);

    await _openDataBoxes(newCipher);
  }

  /// Resolves an interrupted re-encryption. Called from `main()` before any
  /// data box is opened, and defensively from [openBoxes].
  ///
  /// `prepared` → the originals are intact; delete the temporaries and the
  /// pending identity, so the old password keeps working.
  /// `written`  → the temporaries are complete; swap them in and commit the
  /// pending identity, so the new password works.
  Future<void> recoverReencryption({
    void Function(String phase)? onPhase,
  }) async {
    final state = _settingsBox.get(_journalStateKey);
    if (state == null) return;
    if (_boxesOpened) {
      throw StateError('Recovery must run before the data boxes are opened.');
    }

    if (state == _journalPrepared) {
      for (final entry in _journalPaths().values) {
        await _deleteIfExists(entry['from']!);
        await _deleteIfExists(_lockPathFor(entry['from']!));
      }
      await _clearJournal();
      onPhase?.call('rolled_back');
      return;
    }

    if (state == _journalWritten) {
      await _finishReencryption(onPhase: onPhase);
      return;
    }

    // Unknown state from a newer build: leave everything alone rather than
    // guess. The old identity is still the active one.
    throw StateError('Unknown re-encryption journal state: $state');
  }

  /// Steps 4 and 5 of [_reEncryptToCipher]. Idempotent: every rename is
  /// skipped once its source is gone, every write is a plain overwrite, and
  /// the journal is cleared last.
  Future<void> _finishReencryption({
    void Function(String phase)? onPhase,
  }) async {
    for (final entry in _journalPaths().values) {
      final from = File(entry['from']!);
      if (await from.exists()) {
        await from.rename(entry['to']!);
      }
      await _deleteIfExists(_lockPathFor(entry['from']!));
    }
    onPhase?.call('swapped');

    final secure = SecureStorageService();
    await secure.savePasswordVerifier(_settingsBox.get(_journalVerifierKey)!);
    await secure.saveKdfSalt(_settingsBox.get(_journalSaltKey)!);
    await setEncryptionChoice(true);
    await _settingsBox.put('has_password', 'true');
    // Whatever key the biometric path holds was derived from the previous
    // password. Dropping it makes the next biometric attempt fall through to
    // the password, which re-saves a fresh key (unlock_screen.dart).
    await secure.deleteBiometricKeyData();
    await secure.deleteBiometricToken();
    onPhase?.call('committed');

    await _clearJournal();
  }

  Map<String, Map<String, String>> _journalPaths() {
    final raw = _settingsBox.get(_journalPathsKey);
    if (raw == null) return const {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (name, value) => MapEntry(
        name,
        (value as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v as String),
        ),
      ),
    );
  }

  Future<void> _clearJournal() async {
    await _settingsBox.delete(_journalStateKey);
    await _settingsBox.delete(_journalSaltKey);
    await _settingsBox.delete(_journalVerifierKey);
    await _settingsBox.delete(_journalPathsKey);
  }

  String _pathOf(Box<dynamic> box) {
    final path = box.path;
    if (path == null) {
      throw StateError('Box "${box.name}" has no file path.');
    }
    return path;
  }

  /// Hive keeps its lock file beside the box file with a `.lock` extension.
  String _lockPathFor(String boxPath) {
    const ext = '.hive';
    if (boxPath.endsWith(ext)) {
      return '${boxPath.substring(0, boxPath.length - ext.length)}.lock';
    }
    return '$boxPath.lock';
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Where the box files live. Tests use it to inspect the on-disk state.
  @visibleForTesting
  String get homePath => _homePath;

  TransactionModel _copyTransaction(TransactionModel src) {
    final copy = TransactionModel(
      title: src.title,
      amount: src.amount,
      date: src.date,
      isExpense: src.isExpense,
    );
    copy.isRecurring = src.isRecurring;
    copy.subscriptionId = src.subscriptionId;
    return copy;
  }

  SubscriptionModel _copySubscription(SubscriptionModel src) {
    return SubscriptionModel(
      name: src.name,
      amount: src.amount,
      type: src.type,
      billingCycle: src.billingCycle,
      startDate: src.startDate,
      nextDueDate: src.nextDueDate,
      isPaused: src.isPaused,
      notifyDayBefore: src.notifyDayBefore,
      id: src.id,
      createdAt: src.createdAt,
    );
  }

  /// Closes only the encrypted data boxes, leaving the settings box open.
  ///
  /// Used by change-password invoked from the lock screen, where the data
  /// boxes had to be opened temporarily for re-encryption but the app must
  /// remain locked afterwards. Unlike [close], this keeps `_initialized`
  /// true so the lockscreen can still read `getEncryptionChoice()` and the
  /// next unlock can call [openBoxes] directly.
  Future<void> closeDataBoxes() async {
    await _transactionsBox?.close();
    await _subscriptionsBox?.close();
    await _vaultSettingsBox?.close();
    _transactionsBox = null;
    _subscriptionsBox = null;
    _vaultSettingsBox = null;
    _boxesOpened = false;
  }

  Future<void> close() async {
    await _transactionsBox?.close();
    await _subscriptionsBox?.close();
    await _vaultSettingsBox?.close();
    await _settingsBox.close();
    _transactionsBox = null;
    _subscriptionsBox = null;
    _vaultSettingsBox = null;
    _initialized = false;
    _boxesOpened = false;
  }
}
