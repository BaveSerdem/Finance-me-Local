import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:cryptography/cryptography.dart' as crypto_lib;
import 'package:file_picker/file_picker.dart';
import '../models/transaction_model.dart';
import '../models/subscription_model.dart';
import 'database_service.dart';

/// Handles AES-256 encrypted local backup export and import.
class BackupService {
  /// Exports all transactions and subscriptions to an encrypted `.vault` file.
  /// [password] is stretched with PBKDF2 (100k iterations) to derive a 32-byte
  /// AES key. A random 16-byte salt is prepended to the ciphertext.
  ///
  /// Returns the file path on success, or throws on failure.
  Future<String> exportData(String password) async {
    final db = DatabaseService();
    final transactions = db.transactionsBox.values.toList();
    final subscriptions = db.subscriptionsBox.values.toList();

    final payload = jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': transactions.map((t) => _transactionToJson(t)).toList(),
      'subscriptions': subscriptions
          .map((s) => _subscriptionToJson(s))
          .toList(),
    });

    final salt = Uint8List.fromList(enc.IV.fromSecureRandom(16).bytes);
    final key = await _deriveKey(password, salt);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(payload, iv: iv);

    final output = Uint8List.fromList([...salt, ...iv.bytes, ...encrypted.bytes]);

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

  /// Imports data from an encrypted `.vault` file.
  /// [password] must match the one used during export.
  ///
  /// Returns the number of records imported, or throws on failure.
  ///
  /// Throws [BackupDecryptionException] if the password is wrong.
  /// Throws [BackupCorruptionException] if the file is unreadable.
  Future<int> importData(String password, {Uint8List? fileBytes}) async {
    if (fileBytes == null) {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Select Encrypted Backup',
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        throw BackupCorruptionException('Import cancelled by user.');
      }

      fileBytes = result.files.first.bytes;
    }

    if (fileBytes == null || fileBytes.length < 33) {
      throw BackupCorruptionException('Invalid or corrupted backup file.');
    }

    final salt = Uint8List.sublistView(fileBytes, 0, 16);
    final iv = enc.IV(Uint8List.sublistView(fileBytes, 16, 32));
    final ciphertext = enc.Encrypted(Uint8List.sublistView(fileBytes, 32));

    final key = await _deriveKey(password, salt);
    final encrypter = enc.Encrypter(enc.AES(key));

    late String json;
    try {
      json = encrypter.decrypt(ciphertext, iv: iv);
    } catch (_) {
      throw BackupDecryptionException('Wrong password.');
    }

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

      final db = DatabaseService();
      int count = 0;

      for (final tJson in transactionsList) {
        final t = _transactionFromJson(tJson);
        await db.transactionsBox.add(t);
        count++;
      }

      for (final sJson in subscriptionsList) {
        final s = _subscriptionFromJson(sJson);
        await db.subscriptionsBox.add(s);
        count++;
      }

      return count;
    } on FormatException {
      throw BackupCorruptionException('Corrupted backup data.');
    }
  }

  // ---------------------------------------------------------------------------
  // Key derivation
  // ---------------------------------------------------------------------------

  Future<enc.Key> _deriveKey(String password, Uint8List salt) async {
    final algorithm = crypto_lib.Pbkdf2(
      macAlgorithm: crypto_lib.Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final secretKey = await algorithm.deriveKey(
      secretKey: crypto_lib.SecretKey(utf8.encode(password)),
      nonce: salt,
    );
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
        notifyDayBefore: json['enableNotification'] as bool? ?? false,
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
