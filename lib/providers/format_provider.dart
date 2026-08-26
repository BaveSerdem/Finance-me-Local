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

import '../formatting/app_date_format.dart';
import '../formatting/intl_locale.dart';
import '../formatting/money_format.dart';
import '../localization/locale_provider.dart';
import 'currency_provider.dart';
import 'customization_provider.dart';

/// Money formatter for the current settings.
///
/// Widgets should `watch` this rather than building a [MoneyFormat] themselves:
/// because it depends on the currency, the custom symbol, the symbol position
/// and the language, changing any of them re-renders every amount on screen.
final moneyFormatProvider = Provider<MoneyFormat>((ref) {
  final code = ref.watch(currencyProvider);
  final custom = ref.watch(customizationProvider);
  final locale = ref.watch(localeProvider);

  return MoneyFormat(
    symbol: custom.customCurrencySymbol.isNotEmpty
        ? custom.customCurrencySymbol
        : (currencySymbols[code] ?? r'$'),
    symbolLeft: custom.currencyPosition == 'left',
    numberTag: numberTagFor(locale.languageCode),
  );
});

/// Date formatter for the current language.
final dateFormatProvider = Provider<AppDateFormat>((ref) {
  final locale = ref.watch(localeProvider);
  return AppDateFormat(locale.languageCode);
});
