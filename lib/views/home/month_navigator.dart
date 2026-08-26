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
import '../../providers/format_provider.dart';
import '../../providers/period_provider.dart';
import '../../theme/app_metrics.dart';
import '../../theme/app_palette.dart';

/// Moves the view between months, or drops the filter entirely.
///
/// Carries no surface of its own. It sits **inside** whatever card owns it, so
/// giving it a fill made it a fourth floating band on a screen that already had
/// three. The arrows are real `IconButton`s, so they inherit the 48dp minimum
/// from `iconButtonTheme` while the label between them grows freely with the
/// user's font-size setting.
class MonthNavigator extends ConsumerWidget {
  const MonthNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final dates = ref.watch(dateFormatProvider);
    final period = ref.watch(periodProvider);
    final notifier = ref.read(periodProvider.notifier);
    final palette = context.palette;

    final isMonth = period is MonthOf;
    final label = switch (period) {
      MonthOf(:final firstDay) => dates.monthYear(firstDay),
      AllTime() => t('all_time'),
    };

    return Row(
      children: [
        IconButton(
          // Directional glyphs: the platform mirrors these in Arabic, where
          // "previous" points the other way.
          icon: const Icon(Icons.chevron_left),
          tooltip: t('previous_month'),
          onPressed: isMonth ? notifier.showPreviousMonth : null,
        ),
        Expanded(
          child: InkWell(
            // Tapping the label toggles month ↔ all time, so the escape hatch
            // needs no control of its own.
            onTap: isMonth ? notifier.showAllTime : notifier.showCurrentMonth,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Column(
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: palette.inkPrimary,
                        ),
                  ),
                  // The affordance the label needed: nothing previously said it
                  // was tappable, or that "all time" was even reachable.
                  Text(
                    isMonth ? t('tap_for_all_time') : t('tap_for_this_month'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.inkFaint,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: t('next_month'),
          onPressed: isMonth ? notifier.showNextMonth : null,
        ),
      ],
    );
  }
}
