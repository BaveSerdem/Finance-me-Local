// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';

final currencyProvider =
    NotifierProvider<CurrencyNotifier, String>(CurrencyNotifier.new);

const currencySymbols = <String, String>{
  'USD': '\$',
  'EUR': '\u20AC',
  'GBP': '\u00A3',
  'SAR': '\uFDFC',
  'AED': '\u062F.\u0625',
  'AUD': 'A\$',
  'CAD': 'C\$',
  'CHF': 'Fr',
  'CNY': '\u00A5',
  'INR': '\u20B9',
  'JPY': '\u00A5',
  'KRW': '\u20A9',
  'MYR': 'RM',
  'RUB': '\u20BD',
  'SGD': 'S\$',
  'TRY': '\u20BA',
};

class CurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    return DatabaseService().settingsBox.get('currency_code') ?? 'USD';
  }

  Future<void> setCurrency(String code) async {
    await DatabaseService().settingsBox.put('currency_code', code);
    state = code;
  }
}
