import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/subscription_model.dart';
import '../providers/balance_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/customization_provider.dart';
import '../providers/app_colors.dart';
import '../providers/transaction_provider.dart';
import '../providers/subscription_provider.dart';
import '../localization/locale_provider.dart';
import 'settings_screen.dart';
import 'analytics_screen.dart';
import 'recurring_items_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(balanceProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(themeProvider);
    final custom = ref.watch(customizationProvider);
    final disableFeedback = settings.reduceAnimations;
    final t = ref.watch(stringsProvider);

    return PopScope(
      canPop: _selectedTabIndex != 2,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedTabIndex == 2) {
          setState(() => _selectedTabIndex = 0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('finance_me_local')),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: t('settings'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1A1A1E),
                      Color(0xFF0D0D0F),
                    ],
                  ),
                ),
              ),
            ),
            _buildCustomBackground(custom),
            SafeArea(
              child: _selectedTabIndex == 2
                  ? const AnalyticsScreen()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _BalanceHeader(
                          balance: balance,
                          onIncomeTap: () {
                            HapticFeedback.lightImpact();
                            _showFormSheet(context, forceIsExpense: false);
                          },
                          onExpenseTap: () {
                            HapticFeedback.lightImpact();
                            _showFormSheet(context, forceIsExpense: true);
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildTabSelector(colorScheme, disableFeedback),
                        const SizedBox(height: 16),
                        if (custom.showRecurring)
                          _RecurringRow(
                            onIncomeTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RecurringItemsScreen(
                                      showIncome: true),
                                ),
                              );
                            },
                            onSubsTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RecurringItemsScreen(
                                      showIncome: false),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        if (_selectedTabIndex == 0)
                          _TransactionsList(
                            colorScheme: colorScheme,
                            onEditTransaction: _openEditTransactionSheet,
                            onDeleteTransaction: _confirmDeleteTransaction,
                          )
                        else
                          _RecurringListView(
                            colorScheme: colorScheme,
                            onEditSubscription: _openEditSubscriptionSheet,
                            onDeleteSubscription: _confirmDeleteSubscription,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBackground(CustomizationSettings custom) {
    final bgColorHex = custom.bgColor;
    if (bgColorHex == null || bgColorHex.isEmpty) return const SizedBox.shrink();
    final color = AppColors.hex(bgColorHex);
    return Positioned.fill(
      child: Container(color: color),
    );
  }

  Widget _buildTabSelector(ColorScheme colorScheme, bool disableFeedback) {
    final t = ref.watch(stringsProvider);
    return SegmentedButton<int>(
      segments: [
        ButtonSegment(
          value: 0,
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(t('transactions'), maxLines: 1, softWrap: false),
          ),
        ),
        ButtonSegment(
          value: 1,
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(t('subscriptions'), maxLines: 1, softWrap: false),
          ),
        ),
        ButtonSegment(
          value: 2,
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(t('analytics'), maxLines: 1, softWrap: false),
          ),
        ),
      ],
      selected: {_selectedTabIndex},
      onSelectionChanged: (selection) {
        if (!disableFeedback) HapticFeedback.lightImpact();
        setState(() => _selectedTabIndex = selection.first);
      },
    );
  }

  void _showFormSheet(
    BuildContext context, {
    TransactionModel? transaction,
    SubscriptionModel? subscription,
    bool? forceIsExpense,
  }) {
    final themeSettings = ref.read(themeProvider);
    final disableFeedback = themeSettings.reduceAnimations;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        if (subscription != null) {
          return _SubscriptionFormSheet(
            existing: subscription,
            onSave: (
              name,
              amount,
              type,
              billingCycle,
              startDate,
              nextDueDate,
              isPaused,
              notifyDayBefore,
            ) async {
              try {
                final notifier = ref.read(subscriptionProvider.notifier);
                await notifier.updateSubscription(
                  existing: subscription,
                  name: name,
                  amount: amount,
                  type: type,
                  billingCycle: billingCycle,
                  startDate: startDate,
                  nextDueDate: nextDueDate,
                  isPaused: isPaused,
                  notifyDayBefore: notifyDayBefore,
                );
                if (!disableFeedback) HapticFeedback.mediumImpact();
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              } catch (e) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          );
        }
        return _TransactionFormSheet(
          existing: transaction,
          forceIsExpense: forceIsExpense,
          onSave: (title, amount, date, isExpense) async {
            try {
              final notifier = ref.read(transactionProvider.notifier);
              if (transaction != null) {
                await notifier.updateTransaction(
                  existing: transaction,
                  title: title,
                  amount: amount,
                  date: date,
                  isExpense: isExpense,
                );
              } else {
                await notifier.addTransaction(
                  title: title,
                  amount: amount,
                  date: date,
                  isExpense: isExpense,
                );
              }
              if (!disableFeedback) HapticFeedback.mediumImpact();
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            } catch (e) {
              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  void _openEditTransactionSheet(TransactionModel transaction) {
    _showFormSheet(context, transaction: transaction);
  }

  void _openEditSubscriptionSheet(SubscriptionModel subscription) {
    _showFormSheet(context, subscription: subscription);
  }

  void _confirmDeleteTransaction(TransactionModel transaction) {
    _showDeleteConfirmDialog(
      context: context,
      title: transaction.title,
      onConfirm: () async {
        await ref.read(transactionProvider.notifier).deleteTransaction(transaction);
      },
    );
  }

  void _confirmDeleteSubscription(SubscriptionModel subscription) {
    _showDeleteConfirmDialog(
      context: context,
      title: subscription.title,
      onConfirm: () async {
        await ref
            .read(subscriptionProvider.notifier)
            .deleteSubscription(subscription);
      },
    );
  }

  void _showDeleteConfirmDialog({
    required BuildContext context,
    required String title,
    required Future<void> Function() onConfirm,
  }) {
    final t = ref.read(stringsProvider);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(t('delete_record')),
          content: Text(
            '${t('delete_confirm')} "$title"?\n\n${t('delete_confirm_subtitle')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t('cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                try {
                  await onConfirm();
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete: $e'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: Text(t('delete')),
            ),
          ],
        );
      },
    );
  }
}

class _BalanceHeader extends ConsumerWidget {
  const _BalanceHeader({
    required this.balance,
    this.onIncomeTap,
    this.onExpenseTap,
  });

  final Map<String, double> balance;
  final VoidCallback? onIncomeTap;
  final VoidCallback? onExpenseTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final custom = ref.watch(customizationProvider);
    final code = ref.watch(currencyProvider);
    final symbol = custom.customCurrencySymbol.isNotEmpty
        ? custom.customCurrencySymbol
        : (currencySymbols[code] ?? '\u20AC');
    final accentColor = AppColors.hex(custom.accentColorHex);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t('total_balance'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showEditBalanceDialog(context, ref),
                    child: Text(
                      '\u270F',
                      style: TextStyle(
                        fontSize: 13,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                custom.currencyPosition == 'left'
                    ? '$symbol${balance['balance']!.toStringAsFixed(2)}'
                    : '${balance['balance']!.toStringAsFixed(2)}$symbol',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 16),
          color: accentColor,
        ),
        if (custom.showIncomeExpense)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onIncomeTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.call_received,
                          color: AppColors.income,
                          size: 22,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          custom.currencyPosition == 'left'
                              ? '$symbol${balance['totalIncome']!.toStringAsFixed(2)}'
                              : '${balance['totalIncome']!.toStringAsFixed(2)}$symbol',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t('income'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.textSecondary.withAlpha(40),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onExpenseTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.call_made,
                          color: AppColors.expense,
                          size: 22,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          custom.currencyPosition == 'left'
                              ? '$symbol${balance['totalExpenses']!.toStringAsFixed(2)}'
                              : '${balance['totalExpenses']!.toStringAsFixed(2)}$symbol',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t('expenses'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _showEditBalanceDialog(BuildContext context, WidgetRef ref) {
    final t = ref.read(stringsProvider);
    final symbol = currencySymbols[ref.read(currencyProvider)] ?? '\$';
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
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
                prefixText: '$symbol ',
                border: const OutlineInputBorder(),
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
                if (double.tryParse(v) == null) {
                  return t('enter_valid_balance');
                }
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
                  await ref.read(adjustedBalanceProvider.notifier).setBalance(value);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save balance: $e'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: Text(t('save')),
            ),
          ],
        );
      },
    );
  }
}

class _TransactionsList extends ConsumerWidget {
  const _TransactionsList({
    required this.colorScheme,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
  });

  final ColorScheme colorScheme;
  final void Function(TransactionModel) onEditTransaction;
  final void Function(TransactionModel) onDeleteTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);
    final t = ref.watch(stringsProvider);
    final custom = ref.watch(customizationProvider);
    final code = ref.watch(currencyProvider);
    final symbol = custom.customCurrencySymbol.isNotEmpty
        ? custom.customCurrencySymbol
        : (currencySymbols[code] ?? '\u20AC');

    if (transactions.isEmpty) {
      return _EmptyState(
        icon: Icons.inbox_outlined,
        label: t('no_transactions'),
        hint: t('add_first_transaction'),
        colorScheme: colorScheme,
      );
    }

    final sorted = List<TransactionModel>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    final Map<String, List<TransactionModel>> grouped = {};
    for (final txn in sorted) {
      final key = DateFormat.MMMd().format(txn.date).toUpperCase();
      grouped.putIfAbsent(key, () => []).add(txn);
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              entry.key,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          for (int i = 0; i < entry.value.length; i++) ...[
            _LongPressMenuCard(
              onEdit: () => onEditTransaction(entry.value[i]),
              onDelete: () => onDeleteTransaction(entry.value[i]),
              child: Dismissible(
                key: ValueKey(entry.value[i].key),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: colorScheme.onError,
                  ),
                ),
                onDismissed: (_) => onDeleteTransaction(entry.value[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 40,
                        decoration: BoxDecoration(
                          color: entry.value[i].isExpense
                              ? AppColors.expense
                              : AppColors.income,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.value[i].title,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat.jm().format(entry.value[i].date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        custom.currencyPosition == 'left'
                            ? '${entry.value[i].isExpense ? '-' : '+'}$symbol${entry.value[i].amount.toStringAsFixed(2)}'
                            : '${entry.value[i].isExpense ? '-' : '+'}${entry.value[i].amount.toStringAsFixed(2)}$symbol',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: entry.value[i].isExpense
                              ? AppColors.expense
                              : AppColors.income,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i < entry.value.length - 1)
              Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.textSecondary.withAlpha(20),
              ),
        ],
      ],
      ],
    );
  }
}

class _RecurringListView extends ConsumerWidget {
  const _RecurringListView({
    required this.colorScheme,
    required this.onEditSubscription,
    required this.onDeleteSubscription,
  });

  final ColorScheme colorScheme;
  final void Function(SubscriptionModel) onEditSubscription;
  final void Function(SubscriptionModel) onDeleteSubscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionProvider);
    final t = ref.watch(stringsProvider);
    final symbol = currencySymbols[ref.watch(currencyProvider)] ?? '\$';

    if (subscriptions.isEmpty) {
      return _EmptyState(
        icon: Icons.subscriptions_outlined,
        label: t('no_subscriptions'),
        hint: t('add_first_subscription'),
        colorScheme: colorScheme,
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SectionHeader(
          title: t('subscriptions'),
          icon: Icons.repeat,
          color: colorScheme.tertiary,
        ),
        ...subscriptions.map(
          (s) => _SubscriptionTile(
            subscription: s,
            colorScheme: colorScheme,
            symbol: symbol,
            onEdit: () => onEditSubscription(s),
            onDelete: () => onDeleteSubscription(s),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({
    required this.subscription,
    required this.colorScheme,
    required this.symbol,
    required this.onEdit,
    required this.onDelete,
  });

  final SubscriptionModel subscription;
  final ColorScheme colorScheme;
  final String symbol;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    return _LongPressMenuCard(
      onEdit: onEdit,
      onDelete: onDelete,
      child: Dismissible(
        key: ValueKey('legacy_sub_${s.key}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: colorScheme.error,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(Icons.delete_outline, color: colorScheme.onError),
        ),
        onDismissed: (_) => onDelete(),
        child: Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.tertiaryContainer,
              child: Icon(
                Icons.repeat,
                color: colorScheme.onTertiaryContainer,
                size: 20,
              ),
            ),
            title: Text(s.title),
            subtitle: Text(
              'Next: ${DateFormat.yMMMd().format(s.nextBillingDate)}  •  ${s.billingCycle}',
            ),
            trailing: Text(
              '$symbol${s.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LongPressMenuCard extends StatelessWidget {
  const _LongPressMenuCard({
    required this.onEdit,
    required this.onDelete,
    required this.child,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetContext) {
            final colorScheme = Theme.of(context).colorScheme;
            final t = ProviderScope.containerOf(
              sheetContext,
            ).read(stringsProvider);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.edit_outlined,
                        color: colorScheme.primary,
                      ),
                      title: Text(t('edit')),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onEdit();
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: colorScheme.error,
                      ),
                      title: Text(
                        t('delete'),
                        style: TextStyle(color: colorScheme.error),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onDelete();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.label,
    required this.hint,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final String hint;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 80,
              color: colorScheme.outlineVariant.withAlpha(0x88),
            ),
            const SizedBox(height: 20),
            Text(
              label,
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

class _RecurringRow extends ConsumerWidget {
  final VoidCallback? onIncomeTap;
  final VoidCallback? onSubsTap;

  const _RecurringRow({this.onIncomeTap, this.onSubsTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final balance = ref.watch(miniDashboardProvider);
    final custom = ref.watch(customizationProvider);
    final code = ref.watch(currencyProvider);
    final symbol = custom.customCurrencySymbol.isNotEmpty
        ? custom.customCurrencySymbol
        : (currencySymbols[code] ?? '\u20AC');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onIncomeTap,
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_upward,
                    size: 16,
                    color: AppColors.income,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    custom.currencyPosition == 'left'
                        ? '$symbol${balance['monthlyIncome']!.toStringAsFixed(0)}'
                        : '${balance['monthlyIncome']!.toStringAsFixed(0)}$symbol',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.income,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: AppColors.textSecondary.withAlpha(40),
          ),
          const SizedBox(width: 12),
          Text(
            t('recurring'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 24,
            color: AppColors.textSecondary.withAlpha(40),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onSubsTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.arrow_downward,
                    size: 16,
                    color: AppColors.expense,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    custom.currencyPosition == 'left'
                        ? '$symbol${balance['monthlySubs']!.toStringAsFixed(0)}'
                        : '${balance['monthlySubs']!.toStringAsFixed(0)}$symbol',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.expense,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionFormSheet extends StatefulWidget {
  const _TransactionFormSheet({
    this.existing,
    required this.onSave,
    this.forceIsExpense,
  });

  final TransactionModel? existing;
  final Future<void> Function(
    String title,
    double amount,
    DateTime date,
    bool isExpense,
  )
  onSave;
  final bool? forceIsExpense;

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  late DateTime _selectedDate;
  late bool _isExpense;

  bool get _isEditing => widget.existing != null;
  bool get _typeLocked => widget.forceIsExpense != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _amountController.text = existing.amount.toStringAsFixed(2);
      _selectedDate = existing.date;
      _isExpense = existing.isExpense;
    } else {
      _selectedDate = DateTime.now();
      _isExpense = widget.forceIsExpense ?? true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final t = ProviderScope.containerOf(context).read(stringsProvider);
    final symbol = currencySymbols[
      ProviderScope.containerOf(context).read(currencyProvider)
    ] ?? '\$';

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? t('edit_transaction') : t('add_transaction'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: t('title'),
                hintText: t('title_hint_transaction'),
              ),
              validator: (v) => v == null || v.isEmpty ? t('required') : null,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: t('amount'),
                prefixText: '$symbol ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return t('required');
                if (double.tryParse(v) == null || double.parse(v) <= 0) {
                  return t('enter_valid_amount');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: t('date')),
                child: Text(DateFormat.yMMMd().format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: _typeLocked ? 0.6 : 1.0,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(t('expense'))),
                  ButtonSegment(value: false, label: Text(t('income'))),
                ],
                selected: {_isExpense},
                onSelectionChanged: _typeLocked
                    ? null
                    : (selection) {
                        setState(() => _isExpense = selection.first);
                      },
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(
                _isEditing ? t('update_transaction') : t('save_transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      await widget.onSave(
        _titleController.text.trim(),
        double.parse(_amountController.text),
        _selectedDate,
        _isExpense,
      );
      if (!mounted) return;
    }
  }
}

class _SubscriptionFormSheet extends StatefulWidget {
  const _SubscriptionFormSheet({this.existing, required this.onSave});

  final SubscriptionModel? existing;
  final Future<void> Function(
    String name,
    double amount,
    String type,
    String billingCycle,
    DateTime startDate,
    DateTime nextDueDate,
    bool isPaused,
    bool notifyDayBefore,
  )
  onSave;

  @override
  State<_SubscriptionFormSheet> createState() => _SubscriptionFormSheetState();
}

class _SubscriptionFormSheetState extends State<_SubscriptionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  late DateTime _startDate;
  late DateTime _nextDueDate;
  late String _type;
  String _billingCycle = 'Monthly';
  bool _isPaused = false;
  bool _notifyDayBefore = true;

  static const _cycles = [
    'Weekly',
    'Bi-Weekly',
    '3 Weeks',
    'Monthly',
    '3 Months',
    '6 Months',
    '9 Months',
    'Yearly',
  ];
  static const _cycleKeys = [
    'weekly',
    'bi_weekly',
    'every_3_weeks',
    'monthly',
    'every_3_months',
    'every_6_months',
    'every_9_months',
    'yearly',
  ];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _amountController.text = existing.amount.toStringAsFixed(2);
      _startDate = existing.startDate;
      _nextDueDate = existing.nextDueDate;
      _type = existing.type;
      _billingCycle = existing.billingCycle;
      _isPaused = existing.isPaused;
      _notifyDayBefore = existing.notifyDayBefore;
    } else {
      _startDate = DateTime.now();
      _nextDueDate = DateTime.now();
      _type = 'expense';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final t = ProviderScope.containerOf(context).read(stringsProvider);
    final symbol = currencySymbols[
      ProviderScope.containerOf(context).read(currencyProvider)
    ] ?? '\$';

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? t(_type == 'income' ? 'edit_income' : 'edit_subscription') : t('add_subscription'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t('title'),
                hintText: t('title_hint_subscription'),
              ),
              validator: (v) => v == null || v.isEmpty ? t('required') : null,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: t('amount'),
                prefixText: '$symbol ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return t('required');
                if (double.tryParse(v) == null || double.parse(v) <= 0) {
                  return t('enter_valid_amount');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'expense', label: Text(t('expense_type'))),
                      ButtonSegment(value: 'income', label: Text(t('income_type'))),
                    ],
                    selected: {_type},
                    onSelectionChanged: (v) => setState(() => _type = v.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: t('start_date')),
                child: Text(DateFormat.yMMMd().format(_startDate)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _billingCycle,
              decoration: InputDecoration(labelText: t('billing_cycle')),
              items: List.generate(_cycles.length, (i) {
                return DropdownMenuItem(
                  value: _cycles[i],
                  child: Text(t(_cycleKeys[i])),
                );
              }),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _billingCycle = v);
                }
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickNextDueDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: t('next_due')),
                child: Text(DateFormat.yMMMd().format(_nextDueDate)),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t('pause')),
              value: _isPaused,
              onChanged: (v) => setState(() => _isPaused = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t('notify_before')),
              value: _notifyDayBefore,
              onChanged: (v) => setState(() => _notifyDayBefore = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submit,
              child: Text(
                _isEditing ? t('update_subscription') : t('save_subscription'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _pickNextDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _nextDueDate = date);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      await widget.onSave(
        _nameController.text.trim(),
        double.parse(_amountController.text),
        _type,
        _billingCycle,
        _startDate,
        _nextDueDate,
        _isPaused,
        _notifyDayBefore,
      );
      if (!mounted) return;
    }
  }
}
