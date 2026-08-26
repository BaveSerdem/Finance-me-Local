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
import '../../providers/balance_provider.dart';
import '../../providers/format_provider.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_metrics.dart';
import '../../theme/app_palette.dart';
import '../../widgets/money_text.dart';

/// The recurring run-rate, as a card that opens the Recurring destination.
///
/// Three things changed from the strip this replaces. It is one tap target
/// rather than two invisible halves, and it carries a chevron — previously
/// nothing on screen indicated it went anywhere. It uses `money.amount()` like
/// the header directly above it, instead of `money.compact()`: the same concept
/// was printing `$0` sixteen pixels below `$0.00`. And its arrows come from
/// [AppIcons], so they cannot drift from the header's again.
class RecurringSummaryRow extends ConsumerWidget {
  const RecurringSummaryRow({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final summary = ref.watch(recurringSummaryProvider);
    final money = ref.watch(moneyFormatProvider);
    final palette = context.palette;

    return Material(
      color: palette.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md,
          ),
          child: Row(
            children: [
              Icon(AppIcons.recurring, size: 18, color: palette.inkSecondary),
              const SizedBox(width: AppSpace.md),
              Text(
                t('recurring'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.inkSecondary,
                    ),
              ),
              const Spacer(),
              _Figure(
                icon: AppIcons.income,
                color: palette.income,
                text: money.amount(summary.monthlyIncome),
                tone: MoneyTone.income,
              ),
              const SizedBox(width: AppSpace.md),
              _Figure(
                icon: AppIcons.expense,
                color: palette.expense,
                text: money.amount(summary.monthlyExpenses),
                tone: MoneyTone.expense,
              ),
              const SizedBox(width: AppSpace.xs),
              Icon(AppIcons.forward, size: 20, color: palette.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.icon,
    required this.color,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final Color color;
  final String text;
  final MoneyTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpace.xs),
        MoneyText(text, size: MoneySize.caption, tone: tone),
      ],
    );
  }
}
