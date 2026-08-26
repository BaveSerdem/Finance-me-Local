// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import 'format_provider.dart';
import 'period_provider.dart';
import 'transaction_provider.dart';

/// One line in the transaction list — either a day heading or a transaction.
///
/// A flat, pre-computed list is what lets the Overview use `SliverList.builder`
/// and build only the rows on screen. The previous shape was a
/// `Map<String, List<TransactionModel>>` expanded into a `ListView` with
/// `shrinkWrap: true` and `NeverScrollableScrollPhysics` nested inside another
/// `ListView` — which forces every row of every group to be laid out on every
/// frame, however long the history.
@immutable
sealed class TxnRow {
  const TxnRow();
}

/// A day heading: "Today", "Yesterday", or a formatted date.
final class TxnHeader extends TxnRow {
  const TxnHeader(this.label);

  final String label;
}

/// A transaction, plus where it sits in its day group.
final class TxnItem extends TxnRow {
  const TxnItem(this.transaction, {required this.isLastInGroup});

  final TransactionModel transaction;

  /// Drives the hairline between rows — the last row of a day does not get one.
  final bool isLastInGroup;
}

/// The Overview's transaction list, sorted, filtered and grouped.
///
/// All three operations happen **here**, not in `build()`. Sorting a copy of
/// the whole list and rebuilding a `Map` inside a widget's `build` re-ran on
/// every rebuild — including one per keystroke while a form sheet was open
/// above it.
final transactionRowsProvider = Provider<List<TxnRow>>((ref) {
  final transactions = ref.watch(transactionProvider);
  final period = ref.watch(periodProvider);
  final dates = ref.watch(dateFormatProvider);

  final visible = transactions.where((t) => period.contains(t.date)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final rows = <TxnRow>[];
  String? currentLabel;

  for (var i = 0; i < visible.length; i++) {
    final txn = visible[i];
    final label = dates.dayHeader(txn.date);

    if (label != currentLabel) {
      rows.add(TxnHeader(label));
      currentLabel = label;
    }

    final next = i + 1 < visible.length ? visible[i + 1] : null;
    final isLast = next == null || dates.dayHeader(next.date) != label;
    rows.add(TxnItem(txn, isLastInGroup: isLast));
  }

  return rows;
});
