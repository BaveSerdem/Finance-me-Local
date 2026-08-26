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
import '../../models/subscription_model.dart';
import '../../providers/subscription_provider.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_metrics.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/recurring_form_sheet.dart';
import '../../widgets/recurring_item_card.dart';

/// The Recurring destination — income and expenses in two tabs.
///
/// This is now the **only** place recurring items are listed. The Home screen
/// used to carry a second, poorer copy behind a "Subscriptions" tab: no
/// pause control, no income/expense split, a hardcoded English cycle label and
/// every amount in the error colour. Merging removed a duplicated feature, not
/// just duplicated code.
class RecurringTab extends ConsumerStatefulWidget {
  const RecurringTab({super.key});

  @override
  ConsumerState<RecurringTab> createState() => RecurringTabState();
}

class RecurringTabState extends ConsumerState<RecurringTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Opens the form for a new item, typed by whichever tab is showing.
  /// Called by the shell, which owns the floating action button.
  void addItem() {
    _showForm(null, _tabController.index == 0 ? 'income' : 'expense');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final all = ref.watch(subscriptionProvider);

    final income = all.where((s) => s.type == 'income').toList();
    // Anything whose stored `type` is not exactly 'income' counts as an
    // expense, so a corrupt or absent value still appears somewhere instead of
    // vanishing from both tabs.
    final expenses = all.where((s) => s.type != 'income').toList();

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t('monthly_income_label')),
            Tab(text: t('monthly_subs_label')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList(t, income, isIncome: true),
              _buildList(t, expenses, isIncome: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(
    String Function(String) t,
    List<SubscriptionModel> items, {
    required bool isIncome,
  }) {
    if (items.isEmpty) {
      return EmptyState(
        icon: isIncome ? AppIcons.income : Icons.subscriptions_outlined,
        label: isIncome ? t('no_recurring_income') : t('no_recurring_expenses'),
      );
    }

    return ListView.builder(
      key: PageStorageKey('recurring_${isIncome ? 'income' : 'expense'}'),
      padding: const EdgeInsets.all(AppSpace.lg),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return RecurringItemCard(
          key: ValueKey(item.id),
          item: item,
          onTogglePause: () => _togglePause(item),
          onEdit: () => _showForm(item, item.type),
          onDelete: () => _confirmDelete(item),
        );
      },
    );
  }

  Future<void> _togglePause(SubscriptionModel item) async {
    final t = ref.read(stringsProvider);
    try {
      await ref.read(subscriptionProvider.notifier).togglePause(item);
    } catch (e) {
      if (mounted) showErrorSnack(context, t('error_generic'), e);
    }
  }

  Future<void> _confirmDelete(SubscriptionModel item) async {
    final t = ref.read(stringsProvider);

    final confirmed = await showDestructiveConfirmDialog(
      context,
      title: t('delete_record'),
      message: t('delete_recurring_confirm'),
      confirmLabel: t('delete'),
      cancelLabel: t('cancel'),
    );
    if (!confirmed || !mounted) return;

    // Runs after the dialog closes, so a failure reports against a live route
    // rather than one already being torn down.
    try {
      await ref.read(subscriptionProvider.notifier).deleteSubscription(item);
    } catch (e) {
      if (mounted) showErrorSnack(context, t('failed_to_delete'), e);
    }
  }

  void _showForm(SubscriptionModel? existing, String defaultType) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          RecurringFormSheet(existing: existing, defaultType: defaultType),
    );
  }
}
