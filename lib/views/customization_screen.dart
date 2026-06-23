import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/customization_provider.dart';
import '../providers/app_colors.dart';
import '../localization/locale_provider.dart';

class CustomizationScreen extends ConsumerWidget {
  const CustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);
    final customization = ref.watch(customizationProvider);
    final t = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('customization')), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _SectionHeader(title: t('appearance')),
          _ThemeModeTile(settings: themeSettings),
          const SizedBox(height: 4),
          _ColorblindTile(settings: themeSettings),
          const SizedBox(height: 4),
          _AmoledModeTile(customization: customization),
          const SizedBox(height: 4),
          _AccentColorGrid(customization: customization),
          const Divider(height: 32),
          _SectionHeader(title: t('background_color')),
          _BackgroundColorGrid(customization: customization),
          const Divider(height: 32),
          _SectionHeader(title: t('font_size')),
          _FontSizeTile(customization: customization),
          const Divider(height: 32),
          _SectionHeader(title: t('home_screen_customization')),
          _HomeScreenVisibilityTile(customization: customization),
          const Divider(height: 32),
          _SectionHeader(title: t('currency')),
          const _CurrencyCustomizationTile(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.accent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme Mode
// ---------------------------------------------------------------------------

class _ThemeModeTile extends ConsumerWidget {
  final ThemeSettings settings;
  const _ThemeModeTile({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.brightness_6),
        title: Text(t('theme')),
        trailing: DropdownButton<ThemeMode>(
          value: settings.themeMode,
          underline: const SizedBox(),
          items: [
            DropdownMenuItem(value: ThemeMode.system, child: Text(t('system'))),
            DropdownMenuItem(value: ThemeMode.light, child: Text(t('light'))),
            DropdownMenuItem(value: ThemeMode.dark, child: Text(t('dark'))),
          ],
          onChanged: (mode) {
            if (mode != null) {
              if (!settings.reduceAnimations) HapticFeedback.lightImpact();
              ref.read(themeProvider.notifier).setThemeMode(mode);
            }
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Colorblind safe
// ---------------------------------------------------------------------------

class _ColorblindTile extends ConsumerWidget {
  final ThemeSettings settings;
  const _ColorblindTile({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.accessibility_new),
        title: Text(t('colorblind_safe')),
        value: settings.colorPalette == 'colorblind_safe',
        onChanged: (v) {
          HapticFeedback.lightImpact();
          ref
              .read(themeProvider.notifier)
              .setColorPalette(v ? 'colorblind_safe' : 'blue');
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AMOLED Mode
// ---------------------------------------------------------------------------

class _AmoledModeTile extends ConsumerWidget {
  final CustomizationSettings customization;
  const _AmoledModeTile({required this.customization});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.dark_mode),
        title: Text(t('amoled_mode')),
        subtitle: Text(
          t('amoled_mode_sub'),
          style: const TextStyle(fontSize: 12),
        ),
        value: customization.amoledMode,
        onChanged: (v) => ref.read(customizationProvider.notifier).setAmoledMode(v),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accent Color Grid
// ---------------------------------------------------------------------------

class _AccentColorGrid extends ConsumerWidget {
  final CustomizationSettings customization;
  const _AccentColorGrid({required this.customization});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final currentKey = customization.accentColorKey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette, size: 20),
                const SizedBox(width: 12),
                Text(
                  t('primary_color'),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: accentColorOptions.entries.map((entry) {
                final selected = currentKey == entry.key;
                final color = AppColors.hex(entry.value);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(customizationProvider.notifier)
                        .setAccentColor(entry.key);
                  },
                  child: Tooltip(
                    message: t(
                      accentColorLocalizationKeys[entry.key] ?? 'accent_gold',
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary.withAlpha(60),
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.black, size: 18)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background Color
// ---------------------------------------------------------------------------

class _BackgroundColorGrid extends ConsumerWidget {
  final CustomizationSettings customization;
  const _BackgroundColorGrid({required this.customization});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final currentColor = customization.bgColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.format_paint, size: 20),
                const SizedBox(width: 12),
                Text(
                  t('background_color'),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: currentColor == null
                    ? null
                    : () => ref
                        .read(customizationProvider.notifier)
                        .setBgColor(null),
                child: Text(t('default_gradient')),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: accentColorOptions.entries.map((entry) {
                final selected = currentColor == entry.value;
                final color = AppColors.hex(entry.value);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(customizationProvider.notifier)
                        .setBgColor(entry.value);
                  },
                  child: Tooltip(
                    message: t(
                      accentColorLocalizationKeys[entry.key] ?? 'accent_gold',
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary.withAlpha(60),
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.black, size: 18)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Font Size
// ---------------------------------------------------------------------------

class _FontSizeTile extends ConsumerWidget {
  final CustomizationSettings customization;
  const _FontSizeTile({required this.customization});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_fields, size: 20),
                const SizedBox(width: 12),
                Text(t('font_size')),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'small', label: Text(t('font_small'))),
                ButtonSegment(value: 'medium', label: Text(t('font_medium'))),
                ButtonSegment(value: 'large', label: Text(t('font_large'))),
              ],
              selected: {customization.fontSize},
              onSelectionChanged: (v) => ref
                  .read(customizationProvider.notifier)
                  .setFontSize(v.first),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home Screen Visibility
// ---------------------------------------------------------------------------

class _HomeScreenVisibilityTile extends ConsumerWidget {
  final CustomizationSettings customization;
  const _HomeScreenVisibilityTile({required this.customization});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.trending_up),
            title: Text(t('show_income_expense')),
            value: customization.showIncomeExpense,
            onChanged: (v) =>
                ref.read(customizationProvider.notifier).setShowIncomeExpense(v),
          ),
          const Divider(height: 1, indent: 72),
          SwitchListTile(
            secondary: const Icon(Icons.repeat),
            title: Text(t('show_recurring')),
            value: customization.showRecurring,
            onChanged: (v) =>
                ref.read(customizationProvider.notifier).setShowRecurring(v),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Currency Customization
// ---------------------------------------------------------------------------

class _CurrencyCustomizationTile extends ConsumerStatefulWidget {
  const _CurrencyCustomizationTile();

  @override
  ConsumerState<_CurrencyCustomizationTile> createState() =>
      _CurrencyCustomizationTileState();
}

class _CurrencyCustomizationTileState
    extends ConsumerState<_CurrencyCustomizationTile> {
  late TextEditingController _symbolController;

  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController();
  }

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final customization = ref.watch(customizationProvider);

    if (_symbolController.text != customization.customCurrencySymbol) {
      _symbolController.text = customization.customCurrencySymbol;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_money, size: 20),
                const SizedBox(width: 12),
                Text(t('custom_currency')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _symbolController,
              decoration: InputDecoration(
                hintText: '€',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLength: 5,
              onChanged: (v) =>
                  ref.read(customizationProvider.notifier).setCustomCurrencySymbol(v),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'left',
                  label: Text(t('currency_position_left')),
                ),
                ButtonSegment(
                  value: 'right',
                  label: Text(t('currency_position_right')),
                ),
              ],
              selected: {customization.currencyPosition},
              onSelectionChanged: (v) => ref
                  .read(customizationProvider.notifier)
                  .setCurrencyPosition(v.first),
            ),
          ],
        ),
      ),
    );
  }
}


