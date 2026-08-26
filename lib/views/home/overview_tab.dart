// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/locale_provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/customization_provider.dart';
import '../../providers/format_provider.dart';
import '../../providers/period_provider.dart';
import '../../providers/transaction_rows_provider.dart';
import '../../theme/app_metrics.dart';
import '../../widgets/empty_state.dart';
import 'balance_header.dart';
import 'recurring_summary_row.dart';
import 'transaction_row.dart';

/// The Overview destination.
///
/// One `CustomScrollView`, so the header, the period navigator and the
/// transaction list share a single scrollable. The shape this replaces was a
/// `ListView` containing two more `ListView`s with `shrinkWrap: true` and
/// `NeverScrollableScrollPhysics` — every row of every day laid out on every
/// frame, and no row recycling at all.
class OverviewTab extends ConsumerWidget {
  const OverviewTab({
    super.key,
    required this.onAddIncome,
    required this.onAddExpense,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
    required this.onOpenRecurring,
  });

  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final void Function(TransactionModel) onEditTransaction;
  final void Function(TransactionModel) onDeleteTransaction;

  /// Switches the shell to the Recurring destination. Taking a callback rather
  /// than pushing a route is what removes the duplicated recurring list: there
  /// is now one place recurring items are shown.
  final VoidCallback onOpenRecurring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final custom = ref.watch(customizationProvider);
    final money = ref.watch(moneyFormatProvider);
    final dates = ref.watch(dateFormatProvider);
    final rows = ref.watch(transactionRowsProvider);
    final period = ref.watch(periodProvider);

    return CustomScrollView(
      key: const PageStorageKey('overview'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.md,
            AppSpace.lg,
            0,
          ),
          sliver: SliverList.list(
            children: [
              // The period selector lives inside this card, above the figures
              // it scopes — see the note in `balance_header.dart`.
              BalanceHeader(
                onIncomeTap: onAddIncome,
                onExpenseTap: onAddExpense,
              ),
              // The gap belongs to the block that follows it, so hiding the
              // recurring card no longer leaves a stray band behind.
              if (custom.showRecurring) ...[
                const SizedBox(height: AppSpace.md),
                RecurringSummaryRow(onTap: onOpenRecurring),
              ],
            ],
          ),
        ),
        if (rows.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.inbox_outlined,
              // A month with no activity is a different situation from an
              // account with no history, and the old single empty state said
              // "add your first transaction" to someone with two years of them.
              label: period is AllTime
                  ? t('no_transactions')
                  : t('no_transactions_in_period'),
              hint: period is AllTime
                  ? t('add_first_transaction')
                  : t('try_another_month'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              0,
              AppSpace.lg,
              AppSpace.xxl,
            ),
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return switch (row) {
                  TxnHeader(:final label) => TransactionDayHeader(label),
                  TxnItem(:final transaction, :final isLastInGroup) =>
                    TransactionRow(
                      key: ValueKey(transaction.key),
                      transaction: transaction,
                      isLastInGroup: isLastInGroup,
                      money: money,
                      dates: dates,
                      onEdit: () => onEditTransaction(transaction),
                      onDelete: () => onDeleteTransaction(transaction),
                    ),
                };
              },
            ),
          ),
      ],
    );
  }
}
