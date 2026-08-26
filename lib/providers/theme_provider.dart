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
import 'package:hive_ce/hive.dart';
import '../services/database_service.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';

/// Fallback accent, used only if the customization layer ever hands us an empty
/// hex. `CustomizationSettings.accentColorHex` always returns a value, so this
/// is a safety net rather than a live default.
const _fallbackAccent = Color(0xFFC8A96E);

/// Seed used when colourblind mode is on, so the accent hue never competes with
/// the income/expense pair.
const _colorblindSeed = Color(0xFF1565C0);

/// Halves the hue cast that Material 3 bakes into surfaces.
///
/// `ColorScheme.fromSeed` builds its neutral palette as
/// `TonalPalette.of(seedHue, 6.0)` — chroma six, not zero — so every surface
/// carries a faint wash of the user's accent. That is deliberate Material
/// behaviour, but in a finance app it competes with the semantic income/expense
/// pair: a yellow or pink accent makes green and red measurably harder to
/// separate at a glance.
///
/// Only the surface family is touched. Every `on*` colour keeps its Material
/// value, so contrast is unaffected.
ColorScheme _softenSurfaceCast(ColorScheme scheme) {
  Color soften(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withSaturation(hsl.saturation * 0.5).toColor();
  }

  return scheme.copyWith(
    surface: soften(scheme.surface),
    surfaceDim: soften(scheme.surfaceDim),
    surfaceBright: soften(scheme.surfaceBright),
    surfaceContainerLowest: soften(scheme.surfaceContainerLowest),
    surfaceContainerLow: soften(scheme.surfaceContainerLow),
    surfaceContainer: soften(scheme.surfaceContainer),
    surfaceContainerHigh: soften(scheme.surfaceContainerHigh),
    surfaceContainerHighest: soften(scheme.surfaceContainerHighest),
  );
}

/// Parses `#RRGGBB` or `#AARRGGBB` into a [Color]. Single parser for the app.
Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

double _fontScale(String? fontSize) {
  switch (fontSize) {
    case 'small':
      return 0.85;
    case 'large':
      return 1.15;
    default:
      return 1.0;
  }
}

class ThemeSettings {
  final ThemeMode themeMode;
  final String colorPalette;
  final bool reduceAnimations;

  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.colorPalette = 'blue',
    this.reduceAnimations = false,
  });

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    String? colorPalette,
    bool? reduceAnimations,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      colorPalette: colorPalette ?? this.colorPalette,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
    );
  }
}

final themeProvider = NotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
  ThemeSettingsNotifier.new,
);

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  static const _themeModeKey = 'theme_mode';
  static const _colorPaletteKey = 'color_palette';
  static const _reduceAnimationsKey = 'reduce_animations';

  @override
  ThemeSettings build() {
    final box = DatabaseService().settingsBox;
    final themeModeStr = box.get(_themeModeKey);
    final palette = box.get(_colorPaletteKey);
    final reduceStr = box.get(_reduceAnimationsKey);

    ThemeMode mode = ThemeMode.system;
    if (themeModeStr == 'light') mode = ThemeMode.light;
    if (themeModeStr == 'dark') mode = ThemeMode.dark;

    return ThemeSettings(
      themeMode: mode,
      colorPalette: _resolvePalette(palette),
      reduceAnimations: reduceStr?.toLowerCase() == 'true',
    );
  }

  Box<String> get _box => DatabaseService().settingsBox;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    String value = 'system';
    if (mode == ThemeMode.light) value = 'light';
    if (mode == ThemeMode.dark) value = 'dark';
    await _box.put(_themeModeKey, value);
  }

  Future<void> setColorPalette(String palette) async {
    final resolved = _resolvePalette(palette);
    state = state.copyWith(colorPalette: resolved);
    await _box.put(_colorPaletteKey, resolved);
  }

  Future<void> setReduceAnimations(bool value) async {
    state = state.copyWith(reduceAnimations: value);
    await _box.put(_reduceAnimationsKey, value.toString());
  }

  /// `colorPalette` is effectively a boolean: the only writer is the colourblind
  /// switch, which stores `'colorblind_safe'` or `'blue'`. Older installs may
  /// still hold a value from a retired six-colour picker (`'emerald'`, …); those
  /// resolve to `'blue'`, which is behaviourally identical because the theme
  /// seed comes from the user's accent, not from this key.
  ///
  /// The stored key and its values are never rewritten — only interpreted.
  String _resolvePalette(String? stored) =>
      stored == 'colorblind_safe' ? 'colorblind_safe' : 'blue';
}

/// Whether the **platform** is asking for reduced motion.
///
/// Read from `PlatformDispatcher` rather than `MediaQuery` because the theme is
/// built above `MaterialApp`, where no `MediaQuery` exists yet — and because
/// `NotificationService` and other context-free code would otherwise have no
/// way to see it. The observer keeps it live: Android can flip
/// "Remove animations" while the app is running.
class PlatformMotionNotifier extends Notifier<bool> with WidgetsBindingObserver {
  @override
  bool build() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return binding.platformDispatcher.accessibilityFeatures.disableAnimations;
  }

  @override
  void didChangeAccessibilityFeatures() {
    state = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
  }
}

final platformMotionProvider =
    NotifierProvider<PlatformMotionNotifier, bool>(PlatformMotionNotifier.new);

/// The flag every animation and haptic should actually consult.
///
/// Either the user's own switch **or** the system accessibility setting is
/// enough. Honouring only the in-app switch meant a user who had already asked
/// Android to remove animations still got them here, and had to ask twice.
///
/// The switch in Settings deliberately shows `themeProvider.reduceAnimations`,
/// not this: binding the control to the combined value would render it stuck
/// "on" — and unturnable-off — whenever the OS flag was set.
final reduceMotionProvider = Provider<bool>((ref) {
  return ref.watch(themeProvider).reduceAnimations ||
      ref.watch(platformMotionProvider);
});

ThemeData buildThemeData({
  required Brightness brightness,
  required String colorPalette,
  required bool reduceAnimations,
  String? accentColorHex,
  String? bgColorHex,
  bool amoledMode = false,
  String fontSize = 'medium',
}) {
  final isColorblind = colorPalette == 'colorblind_safe';
  final isDark = brightness == Brightness.dark;

  ColorScheme colorScheme;
  final seedColor = isColorblind
      ? _colorblindSeed
      : (accentColorHex != null && accentColorHex.isNotEmpty)
          ? hexToColor(accentColorHex)
          : _fallbackAccent;

  if (isColorblind) {
    colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      error: const Color(0xFFE65100),
    );
  } else {
    colorScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  }

  colorScheme = _softenSurfaceCast(colorScheme);

  // The user's background choice tints the surface family only. It is never
  // painted as an opaque layer: the same twelve swatches feed both the accent
  // grid and the background grid, so picking white used to leave near-white
  // text on a white fill (1.14:1, against a 4.5:1 minimum). Leaving every
  // `on*` colour to Material keeps contrast correct by construction, whichever
  // swatch is chosen.
  final bgTint = (bgColorHex != null && bgColorHex.isNotEmpty)
      ? hexToColor(bgColorHex)
      : null;
  if (bgTint != null) {
    final amount = isDark ? 0.14 : 0.08;
    Color mix(Color base) => Color.lerp(base, bgTint, amount)!;
    colorScheme = colorScheme.copyWith(
      surface: mix(colorScheme.surface),
      surfaceContainerLowest: mix(colorScheme.surfaceContainerLowest),
      surfaceContainerLow: mix(colorScheme.surfaceContainerLow),
      surfaceContainer: mix(colorScheme.surfaceContainer),
      surfaceContainerHigh: mix(colorScheme.surfaceContainerHigh),
      surfaceContainerHighest: mix(colorScheme.surfaceContainerHighest),
    );
  }

  // AMOLED deliberately wins over the tint — true black is the whole point.
  //
  // The whole container ramp is restated, not just `surface`. Overriding the
  // base alone left `surfaceContainerLow/High` at their ordinary dark-theme
  // greys, so a card sat as a visibly light block on pure black; the old code
  // papered over that with a hardcoded card colour in `cardTheme`. Restating
  // the ramp keeps it monotonic — black, then progressively lighter — so
  // `AppPalette`'s raised and well tokens stay correct here for free.
  if (amoledMode && isDark) {
    colorScheme = colorScheme.copyWith(
      surface: Colors.black,
      onSurface: const Color(0xFFF0EDE8),
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0B0B0D),
      surfaceContainer: const Color(0xFF111114),
      surfaceContainerHigh: const Color(0xFF17171B),
      surfaceContainerHighest: const Color(0xFF1D1D22),
    );
  }

  final inputFillColor = isDark
      ? colorScheme.surfaceContainerHighest.withAlpha(0x55)
      : colorScheme.surfaceContainerHighest.withAlpha(0x44);

  final fontScale = _fontScale(fontSize);

  final baseTextTheme = isDark
      ? ThemeData.dark().textTheme
      : ThemeData.light().textTheme;

  final scaledTextTheme = TextTheme(
    displayLarge: baseTextTheme.displayLarge?.copyWith(fontSize: 57 * fontScale),
    displayMedium: baseTextTheme.displayMedium?.copyWith(fontSize: 45 * fontScale),
    displaySmall: baseTextTheme.displaySmall?.copyWith(fontSize: 36 * fontScale),
    headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontSize: 32 * fontScale),
    headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontSize: 28 * fontScale),
    headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontSize: 24 * fontScale),
    titleLarge: baseTextTheme.titleLarge?.copyWith(fontSize: 22 * fontScale),
    titleMedium: baseTextTheme.titleMedium?.copyWith(fontSize: 16 * fontScale),
    titleSmall: baseTextTheme.titleSmall?.copyWith(fontSize: 14 * fontScale),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 16 * fontScale),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 14 * fontScale),
    bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: 12 * fontScale),
    labelLarge: baseTextTheme.labelLarge?.copyWith(fontSize: 14 * fontScale),
    labelMedium: baseTextTheme.labelMedium?.copyWith(fontSize: 12 * fontScale),
    labelSmall: baseTextTheme.labelSmall?.copyWith(fontSize: 11 * fontScale),
  );

  final palette = AppPalette.fromScheme(colorScheme, colourblind: isColorblind);

  // One rounded shape, reused wherever a component takes a `shape` rather than
  // a `borderRadius`.
  final rowShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
    side: BorderSide(color: palette.hairline),
  );

  // Every button gets a 48dp minimum height. Material 3's own default is 40,
  // which is below the platform's minimum touch target — so every button in the
  // app was short by 8dp, and fixing them individually would have meant
  // touching each call site and hoping the next one remembered.
  final buttonStyle = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(64, AppTap.min)),
    shape: WidgetStatePropertyAll(rowShape),
  );

  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: brightness,
    textTheme: scaledTextTheme,
    extensions: [palette],
    scaffoldBackgroundColor: (amoledMode && isDark) ? Colors.black : null,

    // ---- Depth ------------------------------------------------------------
    // Tone plus a hairline, never a shadow. A shadow needs something to fall
    // on, so it vanishes in AMOLED and muddies the user's background tint —
    // and `AppCard` already documented this rule while `cardTheme` contradicted
    // it with `elevation: 0.5`.
    cardTheme: CardThemeData(
      elevation: 0,
      color: palette.surfaceRaised,
      shape: cardShape,
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
    ),

    // ---- Chrome -----------------------------------------------------------
    // `scrolledUnderElevation: 0` and a transparent tint: without them M3
    // repaints the bar in a primary-tinted overlay as content scrolls beneath
    // it, which on the Overview's `CustomScrollView` meant the header changed
    // colour mid-scroll and fought the user's background tint.
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.inkPrimary,
      titleTextStyle: scaledTextTheme.titleLarge?.copyWith(
        color: palette.inkPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: palette.accentWash,
      indicatorShape: rowShape,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(
        scaledTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: palette.accent,
      unselectedLabelColor: palette.inkSecondary,
      indicatorColor: palette.accent,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: palette.hairline,
      labelStyle: scaledTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: scaledTextTheme.titleSmall,
    ),

    // ---- Controls ---------------------------------------------------------
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(style: buttonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size.square(AppTap.min)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, AppTap.min)),
        shape: WidgetStatePropertyAll(rowShape),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accentWash
              : Colors.transparent,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: rowShape,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.xs,
      ),
      minVerticalPadding: AppSpace.sm,
      iconColor: palette.inkSecondary,
      textColor: palette.inkPrimary,
    ),
    dividerTheme: DividerThemeData(
      color: palette.hairline,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.accent,
      circularTrackColor: palette.surfaceWell,
    ),

    // ---- Overlays ---------------------------------------------------------
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: rowShape,
      insetPadding: const EdgeInsets.all(AppSpace.lg),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
    ),

    // ---- Input ------------------------------------------------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: 14,
      ),
    ),

    // Deliberately absent: `chipTheme` (the app builds no `Chip`) and
    // `switchTheme` (Material 3's default already derives every state from the
    // `ColorScheme`, so restating it would only risk breaking the on/off
    // contrast across the user's twelve accents). Configuring a widget that is
    // never built, or restating a default, is noise that later reads as intent.
  );

  if (reduceAnimations) {
    return theme.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      splashFactory: NoSplash.splashFactory,
    );
  }

  return theme;
}
