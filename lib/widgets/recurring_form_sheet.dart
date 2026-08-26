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

import '../localization/locale_provider.dart';
import '../models/billing_cycle.dart';
import '../models/subscription_model.dart';
import '../providers/format_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_metrics.dart';
import 'app_segmented.dart';
import 'app_snack.dart';

/// The single sheet for creating and editing a recurring item.
///
/// The app previously had two: this one, and `_SubscriptionFormSheet` inside
/// `home_screen.dart`. They wrote the same eight fields, but differed in field
/// order, in labels for identical fields, and — dangerously — in how they
/// returned their result.
///
/// The Home copy handed its values back through an **eight-positional-argument
/// callback** whose fifth and sixth parameters were both `DateTime`
/// (`startDate`, `nextDueDate`). Swapping those two would have compiled
/// cleanly, passed analysis, and silently corrupted every edited subscription.
/// This version calls the provider directly with named arguments, so the
/// mistake becomes impossible to express.
///
/// The Home copy was also **edit-only**: it was constructed at exactly one
/// site, inside `if (subscription != null)`, so its create branch was
/// unreachable. This sheet handles both, which is why it is the one that
/// survived.
class RecurringFormSheet extends ConsumerStatefulWidget {
  const RecurringFormSheet({
    super.key,
    this.existing,
    required this.defaultType,
  });

  /// Null creates a new item; non-null edits that one.
  final SubscriptionModel? existing;

  /// Which type a newly created item starts as — `'income'` or `'expense'`.
  final String defaultType;

  @override
  ConsumerState<RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<RecurringFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  late String _type;
  late DateTime _startDate;
  late DateTime _nextDueDate;
  late String _billingCycle;
  bool _isPaused = false;
  bool _notifyDayBefore = true;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _amountController.text = existing.amount.toStringAsFixed(2);
      _type = existing.type;
      _startDate = existing.startDate;
      _nextDueDate = existing.nextDueDate;
      _billingCycle = existing.billingCycle;
      _isPaused = existing.isPaused;
      _notifyDayBefore = existing.notifyDayBefore;
    } else {
      _type = widget.defaultType;
      _startDate = DateTime.now();
      _nextDueDate = DateTime.now();
      _billingCycle = BillingCycle.monthly.storageValue;
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    // `ref.watch`, not `ProviderScope.containerOf(context).read` as the
    // original did: with `read` the sheet kept a stale currency and locale if
    // either changed while it was open.
    final t = ref.watch(stringsProvider);
    final money = ref.watch(moneyFormatProvider);
    final dates = ref.watch(dateFormatProvider);

    // Scrollable. This is the app's longest form — two text fields, a
    // segmented control, two date pickers, a dropdown and two switches — and it
    // was a bare `Column` inside a bottom sheet. `isScrollControlled: true`
    // lets the sheet grow to the full screen but does not make its contents
    // scroll, so at the 1.15x font setting with a keyboard open the column
    // simply overflowed. `TransactionFormSheet` was already fixed this way.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.xl,
        AppSpace.xl,
        AppSpace.xl + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing
                  ? t(_type == 'income' ? 'edit_income' : 'edit_subscription')
                  : t('add_recurring'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.xl),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t('recurring_name'),
                hintText: t('recurring_name_hint'),
              ),
              // Trims before checking, so a name of only spaces is rejected
              // rather than stored as an empty string.
              validator: (v) =>
                  v == null || v.trim().isEmpty ? t('required') : null,
              autofocus: true,
            ),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: t('amount'),
                prefixText: '${money.symbol} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return t('required');
                final parsed = double.tryParse(v);
                if (parsed == null || parsed <= 0) {
                  return t('enter_valid_amount');
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpace.lg),
            AppSegmented<String>(
              segments: [
                AppSegment(value: 'expense', label: t('expense_type')),
                AppSegment(value: 'income', label: t('income_type')),
              ],
              selected: _type,
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: AppSpace.lg),
            InkWell(
              onTap: _pickStartDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: t('start_date')),
                child: Text(dates.mediumDate(_startDate)),
              ),
            ),
            // In create mode the start date doubles as the first due date — the
            // item is billed for the first time on the day it starts, so a
            // second, separate picker would invite two conflicting dates. In
            // edit mode both remain adjustable, because editing a live
            // subscription may legitimately move one without the other.
            if (_isEditing) ...[
              const SizedBox(height: AppSpace.lg),
              InkWell(
                onTap: _pickNextDueDate,
                child: InputDecorator(
                  decoration: InputDecoration(labelText: t('next_due')),
                  child: Text(dates.mediumDate(_nextDueDate)),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            DropdownButtonFormField<String>(
              initialValue: _billingCycle,
              // Without this the button sizes to its widest item rather than to
              // the field, so a long translated cycle name overflows instead of
              // ellipsising.
              isExpanded: true,
              decoration: InputDecoration(labelText: t('billing_cycle')),
              items: [
                for (final cycle in BillingCycle.values)
                  DropdownMenuItem(
                    value: cycle.storageValue,
                    child: Text(t(cycle.l10nKey)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _billingCycle = v);
              },
            ),
            const SizedBox(height: AppSpace.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t('pause')),
              // The original showed `t('active')` when `_isPaused` was true —
              // the switch said "Pause: on" with the word "Active" beneath it.
              subtitle: Text(_isPaused ? t('paused_state') : t('active')),
              value: _isPaused,
              onChanged: (v) => setState(() => _isPaused = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t('notify_before')),
              value: _notifyDayBefore,
              onChanged: (v) => setState(() => _notifyDayBefore = v),
            ),
            const SizedBox(height: AppSpace.sm),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEditing ? t('save_recurring') : t('add_recurring')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _startDate = date);
  }

  Future<void> _pickNextDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _nextDueDate = date);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(subscriptionProvider.notifier);
    final name = _nameController.text.trim();
    final amount = double.parse(_amountController.text);

    try {
      if (_isEditing) {
        await notifier.updateSubscription(
          existing: widget.existing!,
          name: name,
          amount: amount,
          type: _type,
          billingCycle: _billingCycle,
          startDate: _startDate,
          nextDueDate: _nextDueDate,
          isPaused: _isPaused,
          notifyDayBefore: _notifyDayBefore,
        );
      } else {
        await notifier.addSubscription(
          name: name,
          amount: amount,
          type: _type,
          billingCycle: _billingCycle,
          startDate: _startDate,
          nextDueDate: _startDate,
          isPaused: _isPaused,
          notifyDayBefore: _notifyDayBefore,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, ref.read(stringsProvider)('error_generic'), e);
      }
    }
  }
}
