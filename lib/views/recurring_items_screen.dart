import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/subscription_model.dart';
import '../providers/subscription_provider.dart';
import '../providers/currency_provider.dart';
import '../localization/locale_provider.dart';

class RecurringItemsScreen extends ConsumerStatefulWidget {
  final bool showIncome;

  const RecurringItemsScreen({super.key, required this.showIncome});

  @override
  ConsumerState<RecurringItemsScreen> createState() =>
      _RecurringItemsScreenState();
}

class _RecurringItemsScreenState extends ConsumerState<RecurringItemsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showIncome ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final all = ref.watch(subscriptionProvider);

    final incomeItems = all.where((s) => s.type == 'income').toList();
    final expenseItems = all.where((s) => s.type == 'expense').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(t('recurring_items')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t('monthly_income_label')),
            Tab(text: t('monthly_subs_label')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(t, incomeItems, 'income'),
          _buildList(t, expenseItems, 'expense'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null, _tabController.index == 0 ? 'income' : 'expense'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(
    String Function(String) t,
    List<SubscriptionModel> items,
    String type,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                type == 'income' ? Icons.call_received : Icons.subscriptions_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.outlineVariant.withAlpha(0x88),
              ),
              const SizedBox(height: 20),
              Text(
                type == 'income' ? t('no_recurring_income') : t('no_recurring_expenses'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _RecurringItemCard(
          item: item,
          onTogglePause: () async {
            try {
              await ref.read(subscriptionProvider.notifier).togglePause(item);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          onEdit: () => _showForm(item, item.type),
          onDelete: () => _confirmDelete(item),
        );
      },
    );
  }

  void _confirmDelete(SubscriptionModel item) {
    final t = ref.read(stringsProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete_record')),
        content: Text(t('delete_recurring_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              try {
                await ref.read(subscriptionProvider.notifier).deleteSubscription(item);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
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
      ),
    );
  }

  void _showForm(SubscriptionModel? existing, String defaultType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RecurringFormSheet(
        existing: existing,
        defaultType: defaultType,
      ),
    );
  }
}

class _RecurringFormSheet extends ConsumerStatefulWidget {
  final SubscriptionModel? existing;
  final String defaultType;

  const _RecurringFormSheet({this.existing, required this.defaultType});

  @override
  ConsumerState<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<_RecurringFormSheet> {
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
      _billingCycle = 'Monthly';
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
              _isEditing ? t(_type == 'income' ? 'edit_income' : 'edit_subscription') : t('add_recurring'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t('recurring_name'),
                hintText: t('recurring_name_hint'),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            InkWell(
              onTap: _pickNextDueDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: t('next_due')),
                child: Text(DateFormat.yMMMd().format(_nextDueDate)),
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
                if (v != null) setState(() => _billingCycle = v);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t('pause')),
              subtitle: Text(_isPaused ? t('active') : ''),
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
              child: Text(_isEditing ? t('save_recurring') : t('add_recurring')),
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
    if (!_formKey.currentState!.validate()) return;

    try {
      if (!_isEditing) {
        await ref.read(subscriptionProvider.notifier).addSubscription(
          name: _nameController.text.trim(),
          amount: double.parse(_amountController.text),
          type: _type,
          billingCycle: _billingCycle,
          startDate: _startDate,
          nextDueDate: _nextDueDate,
          isPaused: _isPaused,
          notifyDayBefore: _notifyDayBefore,
        );
      } else {
        final existing = widget.existing!;
        await ref.read(subscriptionProvider.notifier).updateSubscription(
          existing: existing,
          name: _nameController.text.trim(),
          amount: double.parse(_amountController.text),
          type: _type,
          billingCycle: _billingCycle,
          startDate: _startDate,
          nextDueDate: _nextDueDate,
          isPaused: _isPaused,
          notifyDayBefore: _notifyDayBefore,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _RecurringItemCard extends StatelessWidget {
  final SubscriptionModel item;
  final VoidCallback onTogglePause;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecurringItemCard({
    required this.item,
    required this.onTogglePause,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = ProviderScope.containerOf(context).read(stringsProvider);
    final symbol = currencySymbols[
      ProviderScope.containerOf(context).read(currencyProvider)
    ] ?? '\$';

    final cycleKey = _billingCycleKey(item.billingCycle);
    final nextDueStr = DateFormat.yMMMd().format(item.nextDueDate);

    return Card(
      color: item.isPaused
          ? colorScheme.surfaceContainerHighest.withAlpha(0x44)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.isPaused
              ? colorScheme.outlineVariant.withAlpha(0x66)
              : item.type == 'expense'
                  ? colorScheme.errorContainer
                  : colorScheme.primaryContainer,
          child: Icon(
            item.isPaused
                ? Icons.pause_circle_outline
                : item.type == 'expense'
                    ? Icons.call_made
                    : Icons.call_received,
            color: item.isPaused
                ? colorScheme.onSurfaceVariant
                : item.type == 'expense'
                    ? colorScheme.onErrorContainer
                    : colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: item.isPaused
                    ? TextStyle(color: colorScheme.onSurfaceVariant)
                    : null,
              ),
            ),
            Text(
              '$symbol${item.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: item.isPaused
                    ? colorScheme.onSurfaceVariant
                    : item.type == 'expense'
                        ? colorScheme.error
                        : colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${t('next_due')} $nextDueStr  •  ${t(cycleKey)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                item.isPaused ? Icons.play_circle_outline : Icons.pause_circle_outline,
                color: colorScheme.primary,
              ),
              tooltip: item.isPaused ? t('resume_tooltip') : t('pause_tooltip'),
              onPressed: onTogglePause,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

const _billingCycleToKey = <String, String>{
  'Weekly': 'weekly',
  'Bi-Weekly': 'bi_weekly',
  '3 Weeks': 'every_3_weeks',
  'Monthly': 'monthly',
  '3 Months': 'every_3_months',
  '6 Months': 'every_6_months',
  '9 Months': 'every_9_months',
  'Yearly': 'yearly',
};

String _billingCycleKey(String cycle) {
  return _billingCycleToKey[cycle] ?? cycle;
}
