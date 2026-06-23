/*
 * ============================================================================
 * Project: Finance me Local
 * Author: BaveSerdem
 * Copyright (c) 2026.
 *
 * LICENSE: Personal Non-Commercial Use Only
 * ============================================================================
 */

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
    final cipher = HiveAesCipher(key);
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
