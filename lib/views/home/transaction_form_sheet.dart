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
import '../../providers/format_provider.dart';
import '../../theme/app_metrics.dart';
import '../../widgets/app_segmented.dart';

/// Add or edit a single transaction.
class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({
    super.key,
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
  ) onSave;

  /// Locks the income/expense toggle — set when the sheet is opened from the
  /// income or expense half of the balance header.
  final bool? forceIsExpense;

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
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
    final t = ref.watch(stringsProvider);
    final money = ref.watch(moneyFormatProvider);
    final dates = ref.watch(dateFormatProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    // Scrollable, because at the 1.15x font setting this form is taller than a
    // small phone's remaining space once the keyboard is up — it used to
    // overflow instead of scrolling.
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
              _isEditing ? t('edit_transaction') : t('add_transaction'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.xl),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: t('title'),
                hintText: t('title_hint_transaction'),
              ),
              // Trimmed before validating, so a title of nothing but spaces is
              // rejected rather than stored as an empty name.
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? t('required') : null,
              autofocus: true,
            ),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: t('amount'),
                prefixText: '${money.symbol} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: t('date')),
                child: Text(dates.mediumDate(_selectedDate)),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppSegmented<bool>(
              segments: [
                AppSegment(value: true, label: t('expense')),
                AppSegment(value: false, label: t('income')),
              ],
              selected: _isExpense,
              onChanged: _typeLocked
                  ? null
                  : (value) => setState(() => _isExpense = value),
            ),
            const SizedBox(height: AppSpace.xl),
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
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.onSave(
      _titleController.text.trim(),
      double.parse(_amountController.text),
      _selectedDate,
      _isExpense,
    );
  }
}
