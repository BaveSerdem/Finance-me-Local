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
import '../providers/theme_provider.dart';
import '../providers/customization_provider.dart';
import '../providers/currency_provider.dart';
import '../localization/locale_provider.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../widgets/app_segmented.dart';
import '../widgets/section_header.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/settings_tiles.dart';

class CustomizationScreen extends ConsumerWidget {
  const CustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);
    final customization = ref.watch(customizationProvider);
    final t = ref.watch(stringsProvider);

    return AppScaffold(
      title: t("customization"),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // No `SizedBox` between cards: `cardTheme.margin` already supplies
          // `AppSpace.sm` beneath each one, so the explicit 4s stacked on top
          // and gave this screen a rhythm no other list in the app has.
          SectionHeader(title: t('appearance')),
          _ThemeModeTile(settings: themeSettings),
          _ColorblindTile(settings: themeSettings),
          _AmoledModeTile(customization: customization),
          _ReduceAnimationsTile(settings: themeSettings),
          _AccentColorGrid(customization: customization),
          // The background grid joins Appearance rather than forming its own
          // section. It had a header reading "Background Color" directly above
          // a card whose own heading read "Background Color" — while the accent
          // grid right above it carried its heading inside the card and needed
          // no header at all. Two identical controls, two different structures.
          _BackgroundColorGrid(customization: customization),
          const Divider(height: AppSpace.xxl),
          SectionHeader(title: t('font_size')),
          _FontSizeTile(customization: customization),
          const Divider(height: AppSpace.xxl),
          SectionHeader(title: t('home_screen_customization')),
          _HomeScreenVisibilityTile(customization: customization),
          const Divider(height: AppSpace.xxl),
          SectionHeader(title: t('currency')),
          const _CurrencyPickerTile(),
          const _CurrencyCustomizationTile(),
        ],
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
    return SettingsChoiceTile<ThemeMode>(
      icon: Icons.brightness_6,
      title: t('theme'),
      value: settings.themeMode,
      options: [
        (ThemeMode.system, t('system')),
        (ThemeMode.light, t('light')),
        (ThemeMode.dark, t('dark')),
      ],
      hapticsEnabled: !ref.watch(reduceMotionProvider),
      onChanged: (mode) => ref.read(themeProvider.notifier).setThemeMode(mode),
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
    return SettingsSwitchTile(
      icon: Icons.accessibility_new,
      title: t('colorblind_safe'),
      // The only switch in this section without a subtitle, so its row sat
      // shorter than the two beneath it for no reason a reader could see.
      subtitle: t('colorblind_safe_sub'),
      value: settings.colorPalette == 'colorblind_safe',
      // This tile fired haptics unconditionally while the theme tile beside it
      // respected `reduceAnimations`.
      hapticsEnabled: !ref.watch(reduceMotionProvider),
      onChanged: (v) => ref
          .read(themeProvider.notifier)
          .setColorPalette(v ? 'colorblind_safe' : 'blue'),
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
    final reduceAnimations = ref.watch(reduceMotionProvider);

    return SettingsSwitchTile(
      icon: Icons.dark_mode,
      title: t('amoled_mode'),
      subtitle: t('amoled_mode_sub'),
      value: customization.amoledMode,
      hapticsEnabled: !reduceAnimations,
      onChanged: (v) =>
          ref.read(customizationProvider.notifier).setAmoledMode(v),
    );
  }
}

// ---------------------------------------------------------------------------
// Reduce Animations
// ---------------------------------------------------------------------------

/// Exposes `reduceAnimations`, which had complete plumbing —
/// `ThemeSettingsNotifier.setReduceAnimations`, a persisted key, and honouring
/// code in the theme, the analytics charts and every haptic call — but no
/// control anywhere in the UI. It was an accessibility setting the user could
/// never switch on.
class _ReduceAnimationsTile extends ConsumerWidget {
  final ThemeSettings settings;
  const _ReduceAnimationsTile({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return SettingsSwitchTile(
      icon: Icons.animation,
      title: t('reduce_animations'),
      subtitle: t('reduce_animations_sub'),
      value: settings.reduceAnimations,
      hapticsEnabled: !ref.watch(reduceMotionProvider),
      onChanged: (v) =>
          ref.read(themeProvider.notifier).setReduceAnimations(v),
    );
  }
}

// ---------------------------------------------------------------------------
// Currency Picker
// ---------------------------------------------------------------------------

/// Exposes `CurrencyNotifier.setCurrency`, which existed with a persisted key
/// and a sixteen-entry symbol table but was **called from nowhere** — leaving
/// the app permanently on USD, with a free-text custom symbol field as the only
/// workaround.
class _CurrencyPickerTile extends ConsumerWidget {
  const _CurrencyPickerTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final code = ref.watch(currencyProvider);
    final reduceAnimations = ref.watch(reduceMotionProvider);

    return SettingsChoiceTile<String>(
      icon: Icons.payments_outlined,
      title: t('currency_code'),
      value: code,
      options: [
        for (final entry in currencySymbols.entries)
          (entry.key, '${entry.key}  ${entry.value}'),
      ],
      hapticsEnabled: !reduceAnimations,
      onChanged: (next) => ref.read(currencyProvider.notifier).setCurrency(next),
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
    // The two colour grids were the last places still firing haptics
    // unconditionally, so switching "reduce motion" on silenced every control
    // on this screen except these swatches.
    final reduceMotion = ref.watch(reduceMotionProvider);
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
            const SizedBox(height: AppSpace.lg),
            _SwatchGrid(
              isSelected: (key, hex) => currentKey == key,
              hapticsEnabled: !reduceMotion,
              label: (key) =>
                  t(accentColorLocalizationKeys[key] ?? 'accent_gold'),
              onPick: (key, hex) =>
                  ref.read(customizationProvider.notifier).setAccentColor(key),
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
    final reduceMotion = ref.watch(reduceMotionProvider);
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
            const SizedBox(height: AppSpace.md),
            _SwatchGrid(
              isSelected: (key, hex) => currentColor == hex,
              hapticsEnabled: !reduceMotion,
              label: (key) =>
                  t(accentColorLocalizationKeys[key] ?? 'accent_gold'),
              onPick: (key, hex) =>
                  ref.read(customizationProvider.notifier).setBgColor(hex),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Swatch grid — shared by the accent and background pickers
// ---------------------------------------------------------------------------

/// The twelve-colour picker.
///
/// One widget for both grids. They were byte-identical apart from which setter
/// they called and how they tested for selection, so the 44dp tap target below
/// the platform minimum existed twice, in twelve targets each.
///
/// The circle stays 44 — it is the right visual weight — while the *target*
/// around it reaches [AppTap.min]. Growing the circle instead would have made
/// the grid wrap to three rows at the large font setting.
class _SwatchGrid extends StatelessWidget {
  const _SwatchGrid({
    required this.isSelected,
    required this.label,
    required this.onPick,
    required this.hapticsEnabled,
  });

  /// Given the option's key and its hex, whether it is the current choice.
  /// The accent grid stores the key; the background grid stores the hex.
  final bool Function(String key, String hex) isSelected;

  final String Function(String key) label;
  final void Function(String key, String hex) onPick;
  final bool hapticsEnabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (final entry in accentColorOptions.entries)
          Builder(
            builder: (context) {
              final selected = isSelected(entry.key, entry.value);
              final color = hexToColor(entry.value);

              return Tooltip(
                message: label(entry.key),
                child: InkResponse(
                  onTap: () {
                    if (hapticsEnabled) HapticFeedback.lightImpact();
                    onPick(entry.key, entry.value);
                  },
                  radius: AppTap.min / 2,
                  child: SizedBox(
                    width: AppTap.min,
                    height: AppTap.min,
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color: selected
                                ? palette.inkPrimary
                                : palette.hairline,
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        // The tick is computed from the swatch's own luminance:
                        // hardcoded black vanished on the darker swatches.
                        child: selected
                            ? Icon(
                                Icons.check,
                                color: readableOn(color),
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
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
            AppSegmented<String>(
              segments: [
                AppSegment(value: "small", label: t("font_small")),
                AppSegment(value: "medium", label: t("font_medium")),
                AppSegment(value: "large", label: t("font_large")),
              ],
              selected: customization.fontSize,
              onChanged: (v) =>
                  ref.read(customizationProvider.notifier).setFontSize(v),
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
    final reduceAnimations = ref.watch(reduceMotionProvider);

    return Column(
      children: [
        SettingsSwitchTile(
          icon: Icons.trending_up,
          title: t('show_income_expense'),
          value: customization.showIncomeExpense,
          hapticsEnabled: !reduceAnimations,
          onChanged: (v) => ref
              .read(customizationProvider.notifier)
              .setShowIncomeExpense(v),
        ),
        SettingsSwitchTile(
          icon: Icons.repeat,
          title: t('show_recurring'),
          value: customization.showRecurring,
          hapticsEnabled: !reduceAnimations,
          onChanged: (v) =>
              ref.read(customizationProvider.notifier).setShowRecurring(v),
        ),
      ],
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
  late final TextEditingController _symbolController;

  @override
  void initState() {
    super.initState();
    // Seeded once from the stored value. The previous version created an empty
    // controller and re-assigned `.text` inside `build()`, which fights the
    // user's caret: assigning `text` collapses the selection to the end, so
    // every rebuild mid-edit — and each keystroke causes one, because
    // `onChanged` writes to the provider — could move the cursor.
    _symbolController = TextEditingController(
      text: ref.read(customizationProvider).customCurrencySymbol,
    );
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

    // Fires only when the value actually changes, and the guard makes it a
    // no-op for the change the user just typed — so it re-syncs on an external
    // change (a restore, a wipe) without ever touching the field mid-edit.
    ref.listen(customizationProvider, (previous, next) {
      if (next.customCurrencySymbol != _symbolController.text) {
        _symbolController.text = next.customCurrencySymbol;
      }
    });

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
              decoration: const InputDecoration(
                hintText: '€',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLength: 5,
              onChanged: (v) =>
                  ref.read(customizationProvider.notifier).setCustomCurrencySymbol(v),
            ),
            const SizedBox(height: 12),
            AppSegmented<String>(
              segments: [
                AppSegment(value: "left", label: t("currency_position_left")),
                AppSegment(value: "right", label: t("currency_position_right")),
              ],
              selected: customization.currencyPosition,
              onChanged: (v) => ref
                  .read(customizationProvider.notifier)
                  .setCurrencyPosition(v),
            ),
          ],
        ),
      ),
    );
  }
}


