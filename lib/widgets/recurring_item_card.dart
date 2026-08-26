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

import '../localization/locale_provider.dart';
import '../models/billing_cycle.dart';
import '../models/subscription_model.dart';
import '../providers/format_provider.dart';
import '../theme/app_icons.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import 'money_text.dart';

/// One recurring item.
///
/// Promoted out of `recurring_items_screen.dart` so the single rebuilt
/// Recurring destination owns it. It replaces `_SubscriptionTile` on the old
/// Home screen too — the tile that printed a hardcoded `'Next: '`, the raw
/// English billing-cycle value straight out of Hive, and every amount in the
/// error colour whether the item was income or expense.
class RecurringItemCard extends ConsumerWidget {
  const RecurringItemCard({
    super.key,
    required this.item,
    required this.onTogglePause,
    required this.onEdit,
    required this.onDelete,
  });

  final SubscriptionModel item;
  final VoidCallback onTogglePause;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final tf = ref.watch(stringsFormatProvider);
    final money = ref.watch(moneyFormatProvider);
    final dates = ref.watch(dateFormatProvider);
    final palette = context.palette;

    final isIncome = item.type == 'income';
    final cycleLabel = t(BillingCycle.fromStorage(item.billingCycle).l10nKey);

    return Card(
      color: item.isPaused ? palette.surfaceWell : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: item.isPaused
              ? palette.hairline
              : (isIncome ? palette.incomeWash : palette.expenseWash),
          child: Icon(
            item.isPaused
                ? AppIcons.paused
                : AppIcons.amount(isExpense: !isIncome),
            size: 20,
            color: item.isPaused
                ? palette.inkFaint
                : (isIncome ? palette.income : palette.expense),
          ),
        ),
        // The amount sits beside the name rather than in `trailing`. It used to
        // share `trailing` with the pause button, so the two of them plus a
        // long German or Russian name overflowed the row at the 1.15x font
        // setting. Here each part has a bound: the name flexes, the amount
        // takes what it needs, and the button is the only thing trailing.
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      item.isPaused ? palette.inkSecondary : palette.inkPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            MoneyText(
              money.amount(item.amount),
              tone: isIncome ? MoneyTone.income : MoneyTone.expense,
            ),
          ],
        ),
        subtitle: Text(
          // The subtitle used to report "active" for a paused item, because it
          // read the flag the wrong way round.
          item.isPaused
              ? t('paused_state')
              : tf('recurring_due_line', {
                  'date': dates.mediumDate(item.nextDueDate),
                  'cycle': cycleLabel,
                }),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(item.isPaused ? AppIcons.resume : AppIcons.paused),
          tooltip: item.isPaused ? t('resume_tooltip') : t('pause_tooltip'),
          onPressed: onTogglePause,
        ),
        onTap: onEdit,
        onLongPress: onDelete,
      ),
    );
  }
}
