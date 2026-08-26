// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'dart:typed_data';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';
import '../models/transaction_model_adapter.dart';
import '../models/subscription_model.dart';
import '../models/subscription_model_adapter.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService _instance = DatabaseService._();

  factory DatabaseService() => _instance;

  static const String _transactionsBoxName = 'transactions';
  static const String _subscriptionsBoxName = 'subscriptions';
  static const String _settingsBoxName = 'settings';
  static const String _encryptionEnabledKey = 'encryption_enabled';

  late final Box<String> _settingsBox;

  bool _initialized = false;
  bool _boxesOpened = false;
  Box<TransactionModel>? _transactionsBox;
  Box<SubscriptionModel>? _subscriptionsBox;

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

  Future<void> initialize() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    Hive.registerAdapter(TransactionModelAdapter());
    Hive.registerAdapter(SubscriptionModelAdapter());
    _settingsBox = await Hive.openBox<String>(_settingsBoxName);
    _initialized = true;
  }

  Future<void> openBoxes(Uint8List key) async {
    if (_boxesOpened) return;
    // null (never decided) is treated as encrypted: every pre-existing live
    // user has a password and encrypted boxes but no stored choice flag, so the
    // boxes must open WITH a cipher unless the user explicitly opted out.
    final encrypted = getEncryptionChoice() != false;
    final cipher = encrypted ? HiveAesCipher(key) : null;
    final txBox = await Hive.openBox<TransactionModel>(
      _transactionsBoxName,
      encryptionCipher: cipher,
    );
    final subBox = await Hive.openBox<SubscriptionModel>(
      _subscriptionsBoxName,
      encryptionCipher: cipher,
    );
    _transactionsBox = txBox;
    _subscriptionsBox = subBox;
    _boxesOpened = true;
    await _persistRegeneratedSubscriptionIds();
  }

  /// Legacy records predate the `id` field and had none stored, so the adapter
  /// generates a fresh id on first read. Persist that id exactly once so every
  /// later read finds the stored value and stops regenerating (which would
  /// otherwise defeat `cancelNotification` id-based lookups).
  Future<void> _persistRegeneratedSubscriptionIds() async {
    for (final sub in _subscriptionsBox!.values) {
      if (sub.idWasRegenerated) {
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
    await _settingsBox.deleteFromDisk();

    _transactionsBox = null;
    _subscriptionsBox = null;
    _initialized = false;
    _boxesOpened = false;
  }

  Future<void> reEncryptBoxes(
    Uint8List oldKey,
    Uint8List newKey,
  ) =>
      _reEncryptToCipher(HiveAesCipher(newKey));

  /// Enables encryption for an app currently running with unencrypted boxes.
  ///
  /// Same underlying re-encryption as [reEncryptBoxes]; only the entry point
  /// differs because no password existed before, so there is no old key.
  Future<void> enableEncryption(Uint8List newKey) =>
      _reEncryptToCipher(HiveAesCipher(newKey));

  /// The one re-encryption path, shared by change-password and
  /// enable-encryption.
  ///
  /// Reads every record from the currently open boxes (whatever cipher — or
  /// none — they were opened with), deep-copies it into fresh objects so a
  /// `HiveObject` never lives in two boxes at once, deletes the old files,
  /// reopens under [newCipher] and reinserts. Ordering is load-bearing: the
  /// copy happens *before* `deleteFromDisk`, so a mid-flight failure cannot
  /// leave the old files half-deleted with a reopened box still empty.
  Future<void> _reEncryptToCipher(HiveAesCipher newCipher) async {
    final txMap = _transactionsBox!.toMap();
    final subMap = _subscriptionsBox!.toMap();

    final freshTx = txMap.map((k, v) => MapEntry(k, _copyTransaction(v)));
    final freshSub = subMap.map((k, v) => MapEntry(k, _copySubscription(v)));

    await _transactionsBox!.deleteFromDisk();
    await _subscriptionsBox!.deleteFromDisk();
    _transactionsBox = null;
    _subscriptionsBox = null;

    _transactionsBox = await Hive.openBox<TransactionModel>(
      _transactionsBoxName,
      encryptionCipher: newCipher,
    );
    _subscriptionsBox = await Hive.openBox<SubscriptionModel>(
      _subscriptionsBoxName,
      encryptionCipher: newCipher,
    );

    if (freshTx.isNotEmpty) {
      await _transactionsBox!.putAll(freshTx);
      await _transactionsBox!.flush();
    }
    if (freshSub.isNotEmpty) {
      await _subscriptionsBox!.putAll(freshSub);
      await _subscriptionsBox!.flush();
    }

    _boxesOpened = true;
  }

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
    _transactionsBox = null;
    _subscriptionsBox = null;
    _boxesOpened = false;
  }

  Future<void> close() async {
    await _transactionsBox?.close();
    await _subscriptionsBox?.close();
    await _settingsBox.close();
    _transactionsBox = null;
    _subscriptionsBox = null;
    _initialized = false;
    _boxesOpened = false;
  }
}
