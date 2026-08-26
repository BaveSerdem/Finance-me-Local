// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../formatting/money_format.dart';
import '../localization/locale_provider.dart';
import '../providers/analytics_provider.dart';
import '../providers/format_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_icons.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/money_text.dart';
import 'home/month_navigator.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final data = ref.watch(analyticsProvider);
    final reduceAnimations = ref.watch(reduceMotionProvider);
    final money = ref.watch(moneyFormatProvider);
    final palette = context.palette;

    return CustomScrollView(
      key: const PageStorageKey('analytics'),
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.lg,
            0,
          ),
          // The same navigator the Overview carries, driving the same provider,
          // so paging to March here and there means the same thing.
          sliver: SliverToBoxAdapter(child: MonthNavigator()),
        ),
        if (data.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            // Was `transactions.length < 2`, so a single transaction showed the
            // "not enough data" placeholder instead of a chart of itself.
            child: EmptyState(
              icon: Icons.insights_outlined,
              label: t('no_data'),
              hint: t('add_transactions_to_see'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(AppSpace.lg),
            sliver: SliverList.list(
              children: [
                AppCard(
                  title: t('chart_activity_title'),
                  child: SizedBox(
                    height: 240,
                    child: _ActivityBarChart(
                      buckets: data.buckets,
                      axisMax: niceAxisMax(data.peak),
                      palette: palette,
                      reduceAnimations: reduceAnimations,
                      incomeTooltip: t('income_tooltip'),
                      expensesTooltip: t('expenses_tooltip'),
                      money: money,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                AppCard(
                  title: t('chart_distribution_title'),
                  child: SizedBox(
                    height: 240,
                    child: _DistributionPieChart(
                      totalIncome: data.totalIncome,
                      totalExpenses: data.totalExpenses,
                      palette: palette,
                      reduceAnimations: reduceAnimations,
                      incomeLabel: t('income_label'),
                      expensesLabel: t('expenses_label'),
                      money: money,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                _SummaryStats(
                  net: data.net,
                  incomeCount: data.incomeCount,
                  expenseCount: data.expenseCount,
                  netLabel: t('net_label'),
                  transactionsLabel: t('transactions_count'),
                  money: money,
                ),
                const SizedBox(height: AppSpace.xxl),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActivityBarChart extends StatelessWidget {
  const _ActivityBarChart({
    required this.buckets,
    required this.axisMax,
    required this.palette,
    required this.reduceAnimations,
    required this.incomeTooltip,
    required this.expensesTooltip,
    required this.money,
  });

  final List<ActivityBucket> buckets;
  final double axisMax;
  final AppPalette palette;
  final bool reduceAnimations;
  final String incomeTooltip;
  final String expensesTooltip;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context) {
    // In colourblind mode the two series also differ in outline, so a bar can
    // be identified without reading its hue.
    final border = palette.distinguishByForm
        ? BorderSide(color: palette.inkPrimary, width: 1)
        : BorderSide.none;

    BarChartRodData rod(double value, Color color, {required bool outlined}) {
      return BarChartRodData(
        toY: value,
        color: color,
        width: 12,
        borderSide: outlined ? border : BorderSide.none,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        backDrawRodData: BackgroundBarChartRodData(
          show: true,
          toY: axisMax,
          color: palette.surfaceWell,
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: axisMax,
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                rod(buckets[i].income, palette.income, outlined: false),
                rod(buckets[i].expenses, palette.expense, outlined: true),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= buckets.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Text(
                    buckets[index].label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: palette.inkSecondary),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              // Exactly the gridline interval, so every label sits on a line
              // and the four values are clean fractions of the top.
              interval: axisMax / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  money.axisLabel(value),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: palette.inkFaint),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: axisMax / 4,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: palette.hairline, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? incomeTooltip : expensesTooltip;
              return BarTooltipItem(
                '$label\n${money.amount(rod.toY)}',
                TextStyle(
                  color: rod.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
        ),
      ),
      duration: reduceAnimations
          ? Duration.zero
          : const Duration(milliseconds: AppMotion.base),
    );
  }
}

class _DistributionPieChart extends StatefulWidget {
  const _DistributionPieChart({
    required this.totalIncome,
    required this.totalExpenses,
    required this.palette,
    required this.reduceAnimations,
    required this.incomeLabel,
    required this.expensesLabel,
    required this.money,
  });

  final double totalIncome;
  final double totalExpenses;
  final AppPalette palette;
  final bool reduceAnimations;
  final String incomeLabel;
  final String expensesLabel;
  final MoneyFormat money;

  @override
  State<_DistributionPieChart> createState() => _DistributionPieChartState();
}

class _DistributionPieChartState extends State<_DistributionPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final total = widget.totalIncome + widget.totalExpenses;
    final incomePercent = total > 0 ? widget.totalIncome / total * 100 : 0.0;
    final expensesPercent =
        total > 0 ? widget.totalExpenses / total * 100 : 0.0;

    PieChartSectionData section({
      required int index,
      required Color color,
      required double value,
      required double percent,
      required IconData icon,
    }) {
      final touched = _touchedIndex == index;
      // `readableOn` rather than `onPrimary`/`onError`: the slice is painted in
      // the semantic income/expense colour, which is unrelated to either of
      // those scheme slots, so the old pairing could put white on a light
      // green.
      final ink = readableOn(color);
      return PieChartSectionData(
        color: color,
        value: value,
        title: touched ? '${percent.toStringAsFixed(0)}%' : '',
        radius: touched ? 65 : 55,
        titleStyle: TextStyle(
          color: ink,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        badgeWidget: touched ? Icon(icon, color: ink, size: 18) : null,
        badgePositionPercentageOffset: 0,
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    final touched = response?.touchedSection;
                    _touchedIndex =
                        (!event.isInterestedForInteractions || touched == null)
                            ? -1
                            : touched.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              sections: [
                section(
                  index: 0,
                  color: palette.income,
                  value: widget.totalIncome,
                  percent: incomePercent,
                  icon: AppIcons.income,
                ),
                section(
                  index: 1,
                  color: palette.expense,
                  value: widget.totalExpenses,
                  percent: expensesPercent,
                  icon: AppIcons.expense,
                ),
              ],
            ),
            duration: widget.reduceAnimations
                ? Duration.zero
                : const Duration(milliseconds: AppMotion.base),
          ),
        ),
        const SizedBox(width: AppSpace.lg),
        Expanded(
          flex: 2,
          // The legend is always present, not only while a slice is touched:
          // in colourblind mode it is the only thing naming the two slices.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendItem(
                color: palette.income,
                label: widget.incomeLabel,
                amount: widget.totalIncome,
                percent: incomePercent,
                money: widget.money,
                tone: MoneyTone.income,
              ),
              const SizedBox(height: AppSpace.lg),
              _LegendItem(
                color: palette.expense,
                label: widget.expensesLabel,
                amount: widget.totalExpenses,
                percent: expensesPercent,
                money: widget.money,
                tone: MoneyTone.expense,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.amount,
    required this.percent,
    required this.money,
    required this.tone,
  });

  final Color color;
  final String label;
  final double amount;
  final double percent;
  final MoneyFormat money;
  final MoneyTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.inkSecondary),
              ),
              MoneyText(
                money.amount(amount),
                size: MoneySize.caption,
                tone: tone,
              ),
            ],
          ),
        ),
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _SummaryStats extends StatelessWidget {
  const _SummaryStats({
    required this.net,
    required this.incomeCount,
    required this.expenseCount,
    required this.netLabel,
    required this.transactionsLabel,
    required this.money,
  });

  final double net;
  final int incomeCount;
  final int expenseCount;
  final String netLabel;
  final String transactionsLabel;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Both figures used to be drawn in `colorScheme.onPrimary` — a leftover
    // from an accent gradient that had already been removed, so near-white ink
    // was being painted on a plain card surface.
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: netLabel,
              child: MoneyText(
                money.amount(net),
                size: MoneySize.title,
                tone: net < 0 ? MoneyTone.expense : MoneyTone.income,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: VerticalDivider(width: 1, color: palette.hairline),
          ),
          Expanded(
            child: _StatItem(
              label: transactionsLabel,
              child: MoneyText('$incomeCount / $expenseCount',
                  size: MoneySize.title),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.palette.inkSecondary,
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: AppSpace.xs),
        child,
      ],
    );
  }
}
