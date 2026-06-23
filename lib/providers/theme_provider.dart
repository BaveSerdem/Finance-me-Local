import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import '../services/database_service.dart';

const primaryColorOptions = <String, Color>{
  'blue': Color(0xFF1A73E8),
  'emerald': Color(0xFF2ECC71),
  'purple': Color(0xFF9B59B6),
  'orange': Color(0xFFE67E22),
  'red': Color(0xFFE74C3C),
  'teal': Color(0xFF1ABC9C),
};

const primaryColorLocalizationKeys = <String, String>{
  'blue': 'ocean_blue',
  'emerald': 'emerald_green',
  'purple': 'amethyst_purple',
  'orange': 'sunset_orange',
  'red': 'ruby_red',
  'teal': 'deep_teal',
};

Color _hexToColor(String hex) {
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
  final bool ambientBackground;

  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.colorPalette = 'blue',
    this.reduceAnimations = false,
    this.ambientBackground = true,
  });

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    String? colorPalette,
    bool? reduceAnimations,
    bool? ambientBackground,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      colorPalette: colorPalette ?? this.colorPalette,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      ambientBackground: ambientBackground ?? this.ambientBackground,
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
  static const _ambientBackgroundKey = 'ambient_background';

  @override
  ThemeSettings build() {
    _loadFromStorage();
    return const ThemeSettings();
  }

  Box<String> get _box => DatabaseService().settingsBox;

  Future<void> _loadFromStorage() async {
    final themeModeStr = _box.get(_themeModeKey);
    final palette = _box.get(_colorPaletteKey);
    final reduceStr = _box.get(_reduceAnimationsKey);
    final ambientStr = _box.get(_ambientBackgroundKey);

    ThemeMode mode = ThemeMode.system;
    if (themeModeStr == 'light') mode = ThemeMode.light;
    if (themeModeStr == 'dark') mode = ThemeMode.dark;

    final resolvedPalette = _resolvePalette(palette);

    state = ThemeSettings(
      themeMode: mode,
      colorPalette: resolvedPalette,
      reduceAnimations: reduceStr?.toLowerCase() == 'true',
      ambientBackground: ambientStr == null
          ? true
          : ambientStr.toLowerCase() == 'true',
    );
  }

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
    if (value) {
      state = state.copyWith(ambientBackground: false);
      await _box.put(_ambientBackgroundKey, false.toString());
    }
  }

  Future<void> setAmbientBackground(bool value) async {
    state = state.copyWith(ambientBackground: value);
    await _box.put(_ambientBackgroundKey, value.toString());
  }

  String _resolvePalette(String? stored) {
    if (stored == null) return 'blue';
    if (stored == 'colorblind_safe') return stored;
    if (primaryColorOptions.containsKey(stored)) return stored;
    return 'blue';
  }
}

ThemeData buildThemeData({
  required Brightness brightness,
  required String colorPalette,
  required bool reduceAnimations,
  String? accentColorHex,
  bool amoledMode = false,
  String fontSize = 'medium',
}) {
  final isColorblind = colorPalette == 'colorblind_safe';
  final isDark = brightness == Brightness.dark;

  ColorScheme colorScheme;
  final seedColor = (accentColorHex != null && accentColorHex.isNotEmpty && !isColorblind)
      ? _hexToColor(accentColorHex)
      : isColorblind
          ? const Color(0xFF1565C0)
          : primaryColorOptions[colorPalette] ?? primaryColorOptions['blue']!;

  if (isColorblind) {
    colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      error: const Color(0xFFE65100),
    );
  } else {
    colorScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  }

  if (amoledMode && isDark) {
    colorScheme = colorScheme.copyWith(
      surface: Colors.black,
      onSurface: const Color(0xFFF0EDE8),
      surfaceContainerHighest: const Color(0xFF050505),
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

  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: brightness,
    textTheme: scaledTextTheme,
    scaffoldBackgroundColor: (amoledMode && isDark) ? Colors.black : null,
    cardTheme: CardThemeData(
      elevation: 0.5,
      shadowColor: Colors.black.withAlpha(0x0F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: const EdgeInsets.only(bottom: 8),
      color: (amoledMode && isDark) ? const Color(0xFF0D0D0F) : null,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      backgroundColor: (amoledMode && isDark) ? const Color(0xFF0D0D0F) : colorScheme.surface,
    ),
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
