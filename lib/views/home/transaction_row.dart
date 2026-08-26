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

import '../../formatting/app_date_format.dart';
import '../../formatting/money_format.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_metrics.dart';
import '../../theme/app_palette.dart';
import '../../widgets/money_text.dart';
import '../../widgets/swipe_to_delete.dart';
import 'long_press_menu.dart';

/// A day heading above a group of transactions.
class TransactionDayHeader extends StatelessWidget {
  const TransactionDayHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.sm),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: context.palette.inkSecondary,
            ),
      ),
    );
  }
}

/// One transaction.
///
/// Direction is carried by three channels, not just colour: the leading rule,
/// the explicit `+`/`−` that `MoneyFormat.signed` emits, and the tone. That is
/// what makes colourblind mode need no special case here.
class TransactionRow extends ConsumerWidget {
  const TransactionRow({
    super.key,
    required this.transaction,
    required this.isLastInGroup,
    required this.money,
    required this.dates,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionModel transaction;
  final bool isLastInGroup;
  final MoneyFormat money;
  final AppDateFormat dates;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final directionColor = transaction.isExpense
        ? palette.expense
        : palette.income;

    return Column(
      children: [
        LongPressMenuCard(
          onEdit: onEdit,
          onDelete: onDelete,
          child: SwipeToDelete(
            dismissKey: ValueKey(transaction.key),
            onDismissed: onDelete,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpace.md,
                horizontal: AppSpace.lg,
              ),
              decoration: BoxDecoration(
                color: palette.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: directionColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: palette.inkPrimary),
                        ),
                        Text(
                          dates.time(transaction.date),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: palette.inkSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  MoneyText(
                    money.signed(
                      transaction.amount,
                      isExpense: transaction.isExpense,
                    ),
                    tone: transaction.isExpense
                        ? MoneyTone.expense
                        : MoneyTone.income,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLastInGroup)
          Container(
            height: 0.5,
            margin: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            color: palette.hairline,
          ),
      ],
    );
  }
}
