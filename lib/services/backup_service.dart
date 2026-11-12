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
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:cryptography/cryptography.dart' as crypto_lib;
import 'package:file_picker/file_picker.dart';
import '../models/transaction_model.dart';
import '../models/subscription_model.dart';
import 'database_service.dart';
import 'notification_service.dart';

/// Handles AES-256 encrypted local backup export and import.
///
/// Two file formats exist:
///
/// * **Version 1** (every backup exported by 1.6.3 and earlier):
///   `salt(16) ‖ iv(16) ‖ AES-CTR ciphertext`, unauthenticated. Still read,
///   never written. Its read path is unchanged.
/// * **Version 2** (written from now on):
///   `"FMLV" ‖ 0x02 ‖ salt(16) ‖ nonce(12) ‖ AES-256-GCM ciphertext ‖ tag(16)`.
///   The GCM tag makes a wrong password and a tampered file each fail
///   deterministically instead of depending on garbage failing to parse (M-6).
///
/// Both derive the key from the password with PBKDF2-HMAC-SHA256 at 100,000
/// iterations over the file's salt.
class BackupService {
  static const List<int> _magic = [0x46, 0x4D, 0x4C, 0x56]; // "FMLV"
  static const int _formatVersion = 2;
  static const int _headerLength = 5; // magic + version byte
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  /// Exports all transactions and subscriptions to an encrypted `.vault` file.
  ///
  /// Returns the file path on success, or throws on failure.
  Future<String> exportData(String password) async {
    final output = await buildEncryptedBackup(password);

    final result = await FilePicker.saveFile(
      dialogTitle: 'Save Encrypted Backup',
      fileName: 'finance_me_local_backup.vault',
      type: FileType.any,
      bytes: output,
    );

    if (result == null) {
      throw Exception('Export cancelled by user.');
    }

    return result;
  }

  /// Builds the version-2 backup bytes for the current boxes. Separate from
  /// [exportData] so the format can be exercised without a file dialog.
  Future<Uint8List> buildEncryptedBackup(String password) async {
    final db = DatabaseService();
    final transactions = db.transactionsBox.values.toList();
    final subscriptions = db.subscriptionsBox.values.toList();

    final payload = jsonEncode({
      'version': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': transactions.map((t) => _transactionToJson(t)).toList(),
      'subscriptions': subscriptions
          .map((s) => _subscriptionToJson(s))
          .toList(),
    });

    final salt = _randomBytes(_saltLength);
    final secretKey = await _deriveSecretKey(password, salt);
    final algorithm = crypto_lib.AesGcm.with256bits();
    final sealed = await algorithm.encrypt(
      utf8.encode(payload),
      secretKey: secretKey,
      nonce: algorithm.newNonce(),
    );

    return Uint8List.fromList([
      ..._magic,
      _formatVersion,
      ...salt,
      ...sealed.nonce,
      ...sealed.cipherText,
      ...sealed.mac.bytes,
    ]);
  }

  /// Imports data from an encrypted `.vault` file.
  /// [password] must match the one used during export.
  ///
  /// Returns the number of records imported, or throws on failure.
  ///
  /// Throws [BackupDecryptionException] if the password is wrong.
  /// Throws [BackupCorruptionException] if the file is unreadable.
  ///
  /// Every record is parsed before the first one is written, so a malformed
  /// file is rejected whole rather than half-imported (L-3).
  Future<int> importData(String password, {Uint8List? fileBytes}) async {
    if (fileBytes == null) {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Select Encrypted Backup',
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        throw const BackupCorruptionException('Import cancelled by user.');
      }

      fileBytes = result.files.first.bytes;
    }

    if (fileBytes == null || fileBytes.length < 33) {
      throw const BackupCorruptionException('Invalid or corrupted backup file.');
    }

    late String json;
    if (_isVersion2(fileBytes)) {
      json = await _decryptVersion2(fileBytes, password);
    } else {
      // ---- Version 1 read path: unchanged from 1.6.3 ----
      final salt = Uint8List.sublistView(fileBytes, 0, 16);
      final iv = enc.IV(Uint8List.sublistView(fileBytes, 16, 32));
      final ciphertext = enc.Encrypted(Uint8List.sublistView(fileBytes, 32));

      final key = await _deriveKey(password, salt);
      final encrypter = enc.Encrypter(enc.AES(key));

      try {
        json = encrypter.decrypt(ciphertext, iv: iv);
      } catch (_) {
        throw const BackupDecryptionException('Wrong password.');
      }
    }

    final List<TransactionModel> parsedTransactions;
    final List<SubscriptionModel> parsedSubscriptions;
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final transactionsList =
          (data['transactions'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final subscriptionsList =
          (data['subscriptions'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      parsedTransactions = transactionsList.map(_transactionFromJson).toList();
      parsedSubscriptions =
          subscriptionsList.map(_subscriptionFromJson).toList();
    } catch (_) {
      // A FormatException from jsonDecode, a TypeError from a wrong or
      // missing field, or a bad date string. Nothing has been written yet.
      throw const BackupCorruptionException('Corrupted backup data.');
    }

    final db = DatabaseService();
    int count = 0;

    // Dedup keys for records already present in the target boxes, so an
    // import (or restore) never duplicates existing entries.
    final txKeys = db.transactionsBox.values
        .map(_transactionKey)
        .toSet();
    final existingSubIds = db.subscriptionsBox.values
        .where((s) => s.id.isNotEmpty)
        .map((s) => s.id)
        .toSet();

    for (final t in parsedTransactions) {
      if (txKeys.contains(_transactionKey(t))) continue;
      await db.transactionsBox.add(t);
      txKeys.add(_transactionKey(t));
      count++;
    }

    for (final s in parsedSubscriptions) {
      if (s.id.isNotEmpty && existingSubIds.contains(s.id)) continue;
      await db.subscriptionsBox.add(s);
      existingSubIds.add(s.id);
      count++;

      // A restored subscription should resume its reminders. The backup format
      // preserves `isPaused`, so only schedule it when it wasn't paused and
      // notifications are enabled for it.
      if (!s.isPaused && s.enableNotification) {
        try {
          await NotificationService().scheduleNotification(s);
        } catch (_) {
          // Never fail the whole import because one reminder failed to plan.
        }
      }
    }

    return count;
  }

  // ---------------------------------------------------------------------------
  // Version 2 container
  // ---------------------------------------------------------------------------

  bool _isVersion2(Uint8List bytes) {
    if (bytes.length < _headerLength) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  Future<String> _decryptVersion2(Uint8List bytes, String password) async {
    if (bytes.length <
        _headerLength + _saltLength + _nonceLength + _macLength) {
      throw const BackupCorruptionException('Invalid or corrupted backup file.');
    }
    if (bytes[_magic.length] != _formatVersion) {
      throw const BackupCorruptionException('Unsupported backup version.');
    }

    var offset = _headerLength;
    final salt = Uint8List.sublistView(bytes, offset, offset + _saltLength);
    offset += _saltLength;
    final nonce = Uint8List.sublistView(bytes, offset, offset + _nonceLength);
    offset += _nonceLength;
    final macStart = bytes.length - _macLength;
    final cipherText = Uint8List.sublistView(bytes, offset, macStart);
    final mac = crypto_lib.Mac(Uint8List.sublistView(bytes, macStart));

    final secretKey = await _deriveSecretKey(password, salt);
    final List<int> clear;
    try {
      clear = await crypto_lib.AesGcm.with256bits().decrypt(
        crypto_lib.SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: secretKey,
      );
    } on crypto_lib.SecretBoxAuthenticationError {
      // Wrong password and tampered file are indistinguishable by design;
      // both are reported as the far more likely of the two.
      throw const BackupDecryptionException('Wrong password.');
    }
    return utf8.decode(clear);
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  // ---------------------------------------------------------------------------
  // Key derivation
  // ---------------------------------------------------------------------------

  Future<crypto_lib.SecretKey> _deriveSecretKey(
    String password,
    Uint8List salt,
  ) {
    final algorithm = crypto_lib.Pbkdf2(
      macAlgorithm: crypto_lib.Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    return algorithm.deriveKey(
      secretKey: crypto_lib.SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Version-1 key: the same derivation, wrapped for the `encrypt` package.
  Future<enc.Key> _deriveKey(String password, Uint8List salt) async {
    final secretKey = await _deriveSecretKey(password, salt);
    final keyBytes = await secretKey.extractBytes();
    return enc.Key(Uint8List.fromList(keyBytes));
  }

  // ---------------------------------------------------------------------------
  // Serialization helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _transactionToJson(TransactionModel t) => {
    'title': t.title,
    'amount': t.amount,
    'date': t.date.toIso8601String(),
    'isExpense': t.isExpense,
    'isRecurring': t.isRecurring,
  };

  /// A stable identity for deduplicating transactions across imports.
  ///
  /// Title + amount + date is the natural key for a hand-entered expense: two
  /// imports of the same backup must collapse to one entry, while a genuinely
  /// repeated purchase (same amount, same day) would share the key regardless
  /// of whether it originated locally or from a restore.
  String _transactionKey(TransactionModel t) {
    final d = t.date;
    return '${t.title}|${t.amount}|${d.year}-${d.month}-${d.day}';
  }

  TransactionModel _transactionFromJson(Map<String, dynamic> json) {
    final t = TransactionModel(
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      isExpense: json['isExpense'] as bool,
    );
    // Preserve legacy isRecurring flag from old backups
    t.isRecurring = json['isRecurring'] as bool? ?? false;
    return t;
  }

  Map<String, dynamic> _subscriptionToJson(SubscriptionModel s) => {
    'title': s.title,
    'amount': s.amount,
    'nextBillingDate': s.nextBillingDate.toIso8601String(),
    'billingCycle': s.billingCycle,
    'enableNotification': s.enableNotification,
    'type': s.type,
    'startDate': s.startDate.toIso8601String(),
    'id': s.id,
    'createdAt': s.createdAt.toIso8601String(),
    // Was omitted entirely. Restoring a backup therefore un-paused every paused
    // subscription, and because each still carried its stale next-due date, the
    // catch-up loop then generated one transaction per elapsed cycle — a paused
    // monthly item could produce two years of charges that never happened.
    'isPaused': s.isPaused,
  };

  SubscriptionModel _subscriptionFromJson(Map<String, dynamic> json) =>
      SubscriptionModel(
        name: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        type: (json['type'] as String?) ?? 'expense',
        billingCycle: json['billingCycle'] as String,
        startDate: json.containsKey('startDate')
            ? DateTime.parse(json['startDate'] as String)
            : DateTime.parse(json['nextBillingDate'] as String),
        nextDueDate: DateTime.parse(json['nextBillingDate'] as String),
        // Defaults to `true`, matching the model and the Hive adapter. The
        // importer alone used to default it to `false`, so any backup predating
        // the key restored with every reminder silently switched off.
        notifyDayBefore: json['enableNotification'] as bool? ?? true,
        isPaused: json['isPaused'] as bool? ?? false,
        id: json['id'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );
}

class BackupDecryptionException implements Exception {
  final String message;
  const BackupDecryptionException(this.message);
  @override
  String toString() => message;
}

class BackupCorruptionException implements Exception {
  final String message;
  const BackupCorruptionException(this.message);
  @override
  String toString() => message;
}
