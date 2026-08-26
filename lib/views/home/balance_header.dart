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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/locale_provider.dart';
import '../../providers/balance_provider.dart';
import '../../providers/customization_provider.dart';
import '../../providers/format_provider.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_metrics.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/money_text.dart';
import 'month_navigator.dart';

/// The top of the Overview: the balance, the period selector, and the selected
/// period's activity — as one object.
///
/// The order is load-bearing. Three figures live here at **two different
/// scopes**: the hero balance is all-time (the user's actual money, so scoping
/// it to a month would report an eleven-month-old account as holding only
/// December's net), while income and expenses describe the selected period.
/// Nothing said so, because the period selector sat *below* the figures it
/// governed and so appeared to govern only the transaction list.
///
/// Putting the selector between them makes the sequence read on its own —
/// [all-time balance] → [period] → [that period's activity] → [that period's
/// rows] — which is cheaper and more durable than a caption explaining it.
class BalanceHeader extends ConsumerWidget {
  const BalanceHeader({super.key, this.onIncomeTap, this.onExpenseTap});

  final VoidCallback? onIncomeTap;
  final VoidCallback? onExpenseTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final custom = ref.watch(customizationProvider);
    final money = ref.watch(moneyFormatProvider);
    final summary = ref.watch(balanceProvider);
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.lg,
              AppSpace.lg,
              AppSpace.sm,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t('total_balance'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: palette.inkSecondary,
                            letterSpacing: 0.6,
                          ),
                    ),
                    // Was a bare `Text('✏')` in a `GestureDetector`: a 13×13
                    // tap target with no tooltip and nothing for a screen
                    // reader. `iconButtonTheme` now supplies the 48dp minimum.
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      // `palette.accent` is `colorScheme.primary` — the same
                      // accent every other component uses. The previous version
                      // parsed `accentColorHex` directly, so this one glyph and
                      // the rule below it were a *different* gold from the rest
                      // of the app.
                      color: palette.accent,
                      tooltip: t('edit_balance_tooltip'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showEditBalanceDialog(context, ref),
                    ),
                  ],
                ),
                MoneyText(money.amount(summary.balance), size: MoneySize.hero),
              ],
            ),
          ),
          Divider(height: 1, color: palette.hairline),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.sm),
            child: MonthNavigator(),
          ),
          if (custom.showIncomeExpense) ...[
            Divider(height: 1, color: palette.hairline),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _ActivityColumn(
                      icon: AppIcons.income,
                      color: palette.income,
                      amount: money.amount(summary.income),
                      tone: MoneyTone.income,
                      label: t('income'),
                      onTap: onIncomeTap,
                    ),
                  ),
                  VerticalDivider(width: 1, color: palette.hairline),
                  Expanded(
                    child: _ActivityColumn(
                      icon: AppIcons.expense,
                      color: palette.expense,
                      amount: money.amount(summary.expenses),
                      tone: MoneyTone.expense,
                      label: t('expenses'),
                      onTap: onExpenseTap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditBalanceDialog(BuildContext context, WidgetRef ref) {
    final t = ref.read(stringsProvider);
    final money = ref.read(moneyFormatProvider);
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('set_balance_title')),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: t('amount'),
                hintText: t('balance_hint'),
                prefixText: '${money.symbol} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return t('required');
                if (double.tryParse(v) == null) return t('enter_valid_balance');
                return null;
              },
              autofocus: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final value = double.parse(controller.text);
                try {
                  await ref
                      .read(adjustedBalanceProvider.notifier)
                      .setBalance(value);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    showErrorSnack(context, t('failed_save_balance'), e);
                  }
                }
              },
              child: Text(t('save')),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }
}

class _ActivityColumn extends StatelessWidget {
  const _ActivityColumn({
    required this.icon,
    required this.color,
    required this.amount,
    required this.tone,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String amount;
  final MoneyTone tone;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: AppSpace.xs),
                // `Flexible`, not a fixed width: at the 1.15x font setting a
                // six-figure amount in a language with a trailing currency
                // symbol is wider than half the screen.
                Flexible(child: MoneyText(amount, tone: tone)),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.inkSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
