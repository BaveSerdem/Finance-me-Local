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
import '../../models/transaction_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_snack.dart';
import '../analytics_screen.dart';
import '../settings_screen.dart';
import 'overview_tab.dart';
import 'recurring_tab.dart';
import 'transaction_form_sheet.dart';

/// The app's three destinations.
enum HomeDestination { overview, recurring, analytics }

/// The frame every destination lives in.
///
/// A bottom `NavigationBar` replaces the `SegmentedButton` that used to sit
/// inside the scroll view, which by itself resolves five separate defects:
///
/// * The active segment's label shrank, because a `FittedBox` scaled it down
///   to fit. Each destination is now its own column with an icon as a second
///   channel, so a longer word in German or Russian wraps the label rather
///   than shrinking it.
/// * Analytics replaced the whole body while the other two swapped only the
///   final child, so the balance header appeared and disappeared asymmetrically.
/// * Scroll position was lost on every switch. `IndexedStack` keeps each
///   destination alive, and each carries a `PageStorageKey`.
/// * A `PopScope` hack intercepted the back button purely to undo the analytics
///   special case.
/// * The bar sits below the content, so the last card is no longer hidden under
///   a floating action button.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  HomeDestination _destination = HomeDestination.overview;
  final _recurringKey = GlobalKey<RecurringTabState>();

  void _goTo(HomeDestination destination) {
    if (_destination == destination) return;
    setState(() => _destination = destination);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('finance_me_local')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: t('settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _destination.index,
          children: [
            OverviewTab(
              onAddIncome: () => _openTransactionSheet(forceIsExpense: false),
              onAddExpense: () => _openTransactionSheet(forceIsExpense: true),
              onEditTransaction: (txn) => _openTransactionSheet(existing: txn),
              onDeleteTransaction: _confirmDeleteTransaction,
              onOpenRecurring: () => _goTo(HomeDestination.recurring),
            ),
            RecurringTab(key: _recurringKey),
            const AnalyticsScreen(),
          ],
        ),
      ),
      floatingActionButton: switch (_destination) {
        HomeDestination.overview => FloatingActionButton(
            tooltip: t('add_transaction'),
            onPressed: () => _openTransactionSheet(),
            child: const Icon(Icons.add),
          ),
        HomeDestination.recurring => FloatingActionButton(
            tooltip: t('add_recurring'),
            onPressed: () => _recurringKey.currentState?.addItem(),
            child: const Icon(Icons.add),
          ),
        HomeDestination.analytics => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destination.index,
        onDestinationSelected: (index) =>
            _goTo(HomeDestination.values[index]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: t('overview'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.repeat_outlined),
            selectedIcon: const Icon(Icons.repeat),
            label: t('recurring'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: t('analytics'),
          ),
        ],
      ),
    );
  }

  void _openTransactionSheet({
    TransactionModel? existing,
    bool? forceIsExpense,
  }) {
    final t = ref.read(stringsProvider);
    final reduceMotion = ref.read(reduceMotionProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => TransactionFormSheet(
        existing: existing,
        forceIsExpense: forceIsExpense,
        onSave: (title, amount, date, isExpense) async {
          try {
            final notifier = ref.read(transactionProvider.notifier);
            if (existing != null) {
              await notifier.updateTransaction(
                existing: existing,
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
            if (!reduceMotion) HapticFeedback.mediumImpact();
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          } catch (e) {
            if (sheetContext.mounted) {
              showErrorSnack(sheetContext, t('error_generic'), e);
            }
          }
        },
      ),
    );
  }

  Future<void> _confirmDeleteTransaction(TransactionModel transaction) async {
    final t = ref.read(stringsProvider);

    final confirmed = await showDestructiveConfirmDialog(
      context,
      title: t('delete_record'),
      message: '${t('delete_confirm')} "${transaction.title}"?\n\n'
          '${t('delete_confirm_subtitle')}',
      confirmLabel: t('delete'),
      cancelLabel: t('cancel'),
    );
    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(transactionProvider.notifier)
          .deleteTransaction(transaction);
    } catch (e) {
      if (mounted) showErrorSnack(context, t('failed_to_delete'), e);
    }
  }
}
