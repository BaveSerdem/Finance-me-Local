// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart';

import '../providers/currency_provider.dart';
import 'intl_locale.dart';

/// Formats every money amount in the app.
///
/// Before this existed the app hand-assembled amounts at seventeen call sites,
/// which produced three distinct defects:
///
/// * `'$symbol${value.toStringAsFixed(2)}'` rendered a negative balance as
///   `$-5.00` — the sign landed after the currency mark.
/// * Nine of those sites ignored the user's custom symbol and left/right
///   position entirely, so the whole Analytics screen, the whole Recurring
///   screen and every notification quietly disregarded those settings.
/// * Nothing grouped thousands, so `1234567.89` printed unbroken.
///
/// This is a plain value class, not a provider, because
/// `NotificationService` has neither a `WidgetRef` nor a `BuildContext` and
/// still has to format the amount it puts in a notification body.
class MoneyFormat {
  const MoneyFormat({
    required this.symbol,
    required this.symbolLeft,
    required this.numberTag,
  });

  /// Builds directly from the settings box, for code with no access to
  /// Riverpod. Widgets should watch `moneyFormatProvider` instead so they
  /// rebuild when the user changes any of these.
  factory MoneyFormat.fromSettings(Box<String> box) {
    final custom = box.get('custom_currency_symbol') ?? '';
    final code = box.get('currency_code') ?? 'USD';
    return MoneyFormat(
      symbol: custom.isNotEmpty ? custom : (currencySymbols[code] ?? r'$'),
      symbolLeft: (box.get('currency_position') ?? 'left') == 'left',
      numberTag: numberTagFor(box.get('app_language') ?? 'en'),
    );
  }

  /// The mark shown beside the number — the user's custom symbol when set,
  /// otherwise the symbol for their currency code.
  final String symbol;

  /// Whether the symbol precedes the number.
  final bool symbolLeft;

  /// `intl` tag driving the grouping and decimal separators.
  final String numberTag;

  /// A value that already carries its own sign — a balance, which may be
  /// negative. The sign is hoisted **in front of the symbol**: `-$5.00`.
  String amount(double value) => _render(
        value.abs(),
        sign: value < 0 ? '-' : '',
        decimals: 2,
      );

  /// An unsigned stored magnitude plus an explicit direction. Transactions and
  /// subscriptions store amounts unsigned with a separate `isExpense` flag, so
  /// the sign has to be supplied rather than read off the number.
  String signed(double magnitude, {required bool isExpense}) => _render(
        magnitude.abs(),
        sign: isExpense ? '-' : '+',
        decimals: 2,
      );

  /// No decimals, for dense summary rows where the cents add noise.
  String compact(double value) => _render(
        value.abs(),
        sign: value < 0 ? '-' : '',
        decimals: 0,
      );

  /// Chart axis ticks: no decimals, and thousands shortened to `k` so the
  /// labels stay narrow.
  String axisLabel(double value) {
    final magnitude = value.abs();
    if (magnitude >= 1000) {
      final thousands = magnitude / 1000;
      final text = NumberFormat.decimalPatternDigits(
        locale: numberTag,
        decimalDigits: thousands >= 10 ? 0 : 1,
      ).format(thousands);
      return symbolLeft ? '$symbol${text}k' : '${text}k $symbol';
    }
    return compact(value);
  }

  String _render(
    double magnitude, {
    required String sign,
    required int decimals,
  }) {
    final body = NumberFormat.decimalPatternDigits(
      locale: numberTag,
      decimalDigits: decimals,
    ).format(magnitude);
    // Non-breaking space keeps a trailing symbol on the same line as its value.
    return symbolLeft ? '$sign$symbol$body' : '$sign$body $symbol';
  }
}
