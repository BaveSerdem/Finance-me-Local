import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/currency_provider.dart';
import '../localization/locale_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);
    final settings = ref.watch(themeProvider);
    final t = ref.watch(stringsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final reduceAnimations = settings.reduceAnimations;
    final symbol = currencySymbols[ref.watch(currencyProvider)] ?? '\$';

    final weeklyData = _computeWeeklyData(transactions);
    final totalIncome = transactions
        .where((t) => !t.isExpense)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalExpenses = transactions
        .where((t) => t.isExpense)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final incomeCount =
        transactions.where((t) => !t.isExpense).length;
    final expenseCount =
        transactions.where((t) => t.isExpense).length;

    if (transactions.length < 2) {
      return _EmptyAnalytics(
        colorScheme: colorScheme,
        message: t('not_enough_data'),
        hint: t('add_transactions_for_analytics'),
      );
    }

    final incomeColor = colorScheme.primary;
    final expenseColor = colorScheme.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _ChartCard(
            title: t('chart_weekly_title'),
            colorScheme: colorScheme,
            child: SizedBox(
              height: 240,
              child: _WeeklyBarChart(
                weeklyData: weeklyData,
                incomeColor: incomeColor,
                expenseColor: expenseColor,
                colorScheme: colorScheme,
                reduceAnimations: reduceAnimations,
                incomeTooltip: t('income_tooltip'),
                expensesTooltip: t('expenses_tooltip'),
                symbol: symbol,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ChartCard(
            title: t('chart_distribution_title'),
            colorScheme: colorScheme,
            child: SizedBox(
              height: 240,
              child: _DistributionPieChart(
                totalIncome: totalIncome,
                totalExpenses: totalExpenses,
                incomeColor: incomeColor,
                expenseColor: expenseColor,
                colorScheme: colorScheme,
                reduceAnimations: reduceAnimations,
                incomeLabel: t('income_label'),
                expensesLabel: t('expenses_label'),
                symbol: symbol,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SummaryStats(
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            incomeCount: incomeCount,
            expenseCount: expenseCount,
            colorScheme: colorScheme,
            netLabel: t('net_label'),
            transactionsLabel: t('transactions_count'),
            symbol: symbol,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.colorScheme,
    required this.child,
  });

  final String title;
  final ColorScheme colorScheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surfaceContainerHighest.withAlpha(0x40),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(0x18),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _DaySummary {
  final DateTime date;
  double income = 0;
  double expenses = 0;

  _DaySummary({required this.date});
}

List<_DaySummary> _computeWeeklyData(List<TransactionModel> transactions) {
  final today = DateTime.now();
  final days = List.generate(7, (i) {
    final date = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: 6 - i));
    return _DaySummary(date: date);
  });

  for (final t in transactions) {
    final tDate = DateTime(t.date.year, t.date.month, t.date.day);
    for (int i = 0; i < days.length; i++) {
      if (days[i].date == tDate) {
        if (t.isExpense) {
          days[i].expenses += t.amount;
        } else {
          days[i].income += t.amount;
        }
        break;
      }
    }
  }

  return days;
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({
    required this.weeklyData,
    required this.incomeColor,
    required this.expenseColor,
    required this.colorScheme,
    required this.reduceAnimations,
    required this.incomeTooltip,
    required this.expensesTooltip,
    required this.symbol,
  });

  final List<_DaySummary> weeklyData;
  final Color incomeColor;
  final Color expenseColor;
  final ColorScheme colorScheme;
  final bool reduceAnimations;
  final String incomeTooltip;
  final String expensesTooltip;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final maxY = weeklyData.fold<double>(
      0,
      (max, d) => (d.income > max && d.income > d.expenses)
          ? d.income
          : (d.expenses > max ? d.expenses : max),
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY == 0 ? 100 : maxY * 1.2,
        barGroups: weeklyData.asMap().entries.map((entry) {
          final idx = entry.key;
          final day = entry.value;
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: day.income,
                color: incomeColor,
                width: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY == 0 ? 100 : maxY * 1.2,
                  color: colorScheme.surfaceContainerHighest.withAlpha(0x55),
                ),
              ),
              BarChartRodData(
                toY: day.expenses,
                color: expenseColor,
                width: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY == 0 ? 100 : maxY * 1.2,
                  color: colorScheme.surfaceContainerHighest.withAlpha(0x55),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= weeklyData.length) {
                  return const SizedBox();
                }
                final dayNames = [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ];
                final weekday = weeklyData[idx].date.weekday;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    dayNames[weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  '$symbol${value.toInt()}',
                  style: TextStyle(fontSize: 10, color: colorScheme.outline),
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
          horizontalInterval: maxY == 0 ? 25 : (maxY * 1.2) / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.outlineVariant.withAlpha(0x33),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? incomeTooltip : expensesTooltip;
              return BarTooltipItem(
                '$label\n$symbol${rod.toY.toStringAsFixed(2)}',
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
          : const Duration(milliseconds: 250),
    );
  }
}

class _DistributionPieChart extends StatefulWidget {
  const _DistributionPieChart({
    required this.totalIncome,
    required this.totalExpenses,
    required this.incomeColor,
    required this.expenseColor,
    required this.colorScheme,
    required this.reduceAnimations,
    required this.incomeLabel,
    required this.expensesLabel,
    required this.symbol,
  });

  final double totalIncome;
  final double totalExpenses;
  final Color incomeColor;
  final Color expenseColor;
  final ColorScheme colorScheme;
  final bool reduceAnimations;
  final String incomeLabel;
  final String expensesLabel;
  final String symbol;

  @override
  State<_DistributionPieChart> createState() => _DistributionPieChartState();
}

class _DistributionPieChartState extends State<_DistributionPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.totalIncome + widget.totalExpenses;
    final incomePercent = total > 0 ? (widget.totalIncome / total * 100) : 0.0;
    final expensesPercent = total > 0
        ? (widget.totalExpenses / total * 100)
        : 0.0;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        response.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  color: widget.incomeColor,
                  value: widget.totalIncome,
                  title: _touchedIndex == 0
                      ? '${incomePercent.toStringAsFixed(0)}%'
                      : '',
                  radius: _touchedIndex == 0 ? 65 : 55,
                  titleStyle: TextStyle(
                    color: widget.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  badgeWidget: _touchedIndex == 0
                      ? Icon(
                          Icons.call_received,
                          color: widget.colorScheme.onPrimary,
                          size: 18,
                        )
                      : null,
                  badgePositionPercentageOffset: 0,
                ),
                PieChartSectionData(
                  color: widget.expenseColor,
                  value: widget.totalExpenses,
                  title: _touchedIndex == 1
                      ? '${expensesPercent.toStringAsFixed(0)}%'
                      : '',
                  radius: _touchedIndex == 1 ? 65 : 55,
                  titleStyle: TextStyle(
                    color: widget.colorScheme.onError,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  badgeWidget: _touchedIndex == 1
                      ? Icon(
                          Icons.call_made,
                          color: widget.colorScheme.onError,
                          size: 18,
                        )
                      : null,
                  badgePositionPercentageOffset: 0,
                ),
              ],
            ),
            duration: widget.reduceAnimations
                ? Duration.zero
                : const Duration(milliseconds: 250),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendItem(
                color: widget.incomeColor,
                label: widget.incomeLabel,
                amount: widget.totalIncome,
                percent: incomePercent,
                symbol: widget.symbol,
              ),
              const SizedBox(height: 16),
              _LegendItem(
                color: widget.expenseColor,
                label: widget.expensesLabel,
                amount: widget.totalExpenses,
                percent: expensesPercent,
                symbol: widget.symbol,
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
    required this.symbol,
  });

  final Color color;
  final String label;
  final double amount;
  final double percent;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$symbol${amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
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
    required this.totalIncome,
    required this.totalExpenses,
    required this.incomeCount,
    required this.expenseCount,
    required this.colorScheme,
    required this.netLabel,
    required this.transactionsLabel,
    required this.symbol,
  });

  final double totalIncome;
  final double totalExpenses;
  final int incomeCount;
  final int expenseCount;
  final ColorScheme colorScheme;
  final String netLabel;
  final String transactionsLabel;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.primary.withAlpha(0xCC)],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(0x33),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: netLabel,
              value: totalIncome - totalExpenses,
              color: colorScheme.onPrimary,
              symbol: symbol,
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: colorScheme.onPrimary.withAlpha(0x33),
          ),
          Expanded(
            child: _StatItem(
              label: transactionsLabel,
              value: 0,
              color: colorScheme.onPrimary,
              isTransactionCount: true,
              incomeCount: incomeCount,
              expenseCount: expenseCount,
              symbol: symbol,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.symbol,
    this.isTransactionCount = false,
    this.incomeCount = 0,
    this.expenseCount = 0,
  });

  final String label;
  final double value;
  final Color color;
  final String symbol;
  final bool isTransactionCount;
  final int incomeCount;
  final int expenseCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color.withAlpha(0xCC),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isTransactionCount
              ? '$incomeCount / $expenseCount'
              : '$symbol${value.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            fontSize: 22,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics({
    required this.colorScheme,
    required this.message,
    required this.hint,
  });

  final ColorScheme colorScheme;
  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_chart_outlined,
              size: 80,
              color: colorScheme.outlineVariant.withAlpha(0x88),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
