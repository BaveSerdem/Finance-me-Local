import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';

const accentColorOptions = <String, String>{
  'gold': '#C8A96E',
  'blue': '#5B8DEF',
  'green': '#4C9E6E',
  'purple': '#9B6BE8',
  'pink': '#E87B9B',
  'orange': '#E8923F',
  'cyan': '#5BC4D4',
  'red': '#E85C5C',
  'gray': '#A0A0A0',
  'yellow': '#E8D45C',
  'olive': '#7B9E6E',
  'white': '#FFFFFF',
};

const accentColorLocalizationKeys = <String, String>{
  'gold': 'accent_gold',
  'blue': 'ocean_blue',
  'green': 'emerald_green',
  'purple': 'amethyst_purple',
  'pink': 'accent_pink',
  'orange': 'sunset_orange',
  'cyan': 'accent_cyan',
  'red': 'ruby_red',
  'gray': 'accent_gray',
  'yellow': 'accent_yellow',
  'olive': 'accent_olive',
  'white': 'accent_white',
};

class CustomizationSettings {
  final bool amoledMode;
  final String accentColorKey;
  final String? bgColor;
  final String fontSize;
  final bool showIncomeExpense;
  final bool showRecurring;
  final String customCurrencySymbol;
  final String currencyPosition;

  const CustomizationSettings({
    this.amoledMode = false,
    this.accentColorKey = 'gold',
    this.bgColor,
    this.fontSize = 'medium',
    this.showIncomeExpense = true,
    this.showRecurring = true,
    this.customCurrencySymbol = '',
    this.currencyPosition = 'left',
  });

  static const _bgColorSentinel = Object();

  CustomizationSettings copyWith({
    bool? amoledMode,
    String? accentColorKey,
    Object? bgColor = _bgColorSentinel,
    String? fontSize,
    bool? showIncomeExpense,
    bool? showRecurring,
    String? customCurrencySymbol,
    String? currencyPosition,
  }) {
    return CustomizationSettings(
      amoledMode: amoledMode ?? this.amoledMode,
      accentColorKey: accentColorKey ?? this.accentColorKey,
      bgColor: bgColor == _bgColorSentinel ? this.bgColor : bgColor as String?,
      fontSize: fontSize ?? this.fontSize,
      showIncomeExpense: showIncomeExpense ?? this.showIncomeExpense,
      showRecurring: showRecurring ?? this.showRecurring,
      customCurrencySymbol: customCurrencySymbol ?? this.customCurrencySymbol,
      currencyPosition: currencyPosition ?? this.currencyPosition,
    );
  }

  String get accentColorHex => accentColorOptions[accentColorKey] ?? '#C8A96E';
}

final customizationProvider =
    NotifierProvider<CustomizationNotifier, CustomizationSettings>(
  CustomizationNotifier.new,
);

class CustomizationNotifier extends Notifier<CustomizationSettings> {
  @override
  CustomizationSettings build() {
    try {
      final box = DatabaseService().settingsBox;

      return CustomizationSettings(
        amoledMode: box.get('amoled_mode') == 'true',
        accentColorKey: box.get('accent_color') ?? 'gold',
        bgColor: box.get('bg_color'),
        fontSize: box.get('font_size') ?? 'medium',
        showIncomeExpense: box.get('show_income_expense') != 'false',
        showRecurring: box.get('show_recurring') != 'false',
        customCurrencySymbol: box.get('custom_currency_symbol') ?? '',
        currencyPosition: box.get('currency_position') ?? 'left',
      );
    } on StateError {
      return const CustomizationSettings();
    }
  }

  Future<void> setAmoledMode(bool value) async {
    state = state.copyWith(amoledMode: value);
    await DatabaseService().settingsBox.put('amoled_mode', value.toString());
  }

  Future<void> setAccentColor(String key) async {
    state = state.copyWith(accentColorKey: key);
    await DatabaseService().settingsBox.put('accent_color', key);
  }

  Future<void> setBgColor(String? colorHex) async {
    state = state.copyWith(bgColor: colorHex);
    if (colorHex != null) {
      await DatabaseService().settingsBox.put('bg_color', colorHex);
    } else {
      await DatabaseService().settingsBox.delete('bg_color');
    }
  }

  Future<void> setFontSize(String value) async {
    state = state.copyWith(fontSize: value);
    await DatabaseService().settingsBox.put('font_size', value);
  }

  Future<void> setShowIncomeExpense(bool value) async {
    state = state.copyWith(showIncomeExpense: value);
    await DatabaseService()
        .settingsBox
        .put('show_income_expense', value.toString());
  }

  Future<void> setShowRecurring(bool value) async {
    state = state.copyWith(showRecurring: value);
    await DatabaseService().settingsBox.put('show_recurring', value.toString());
  }

  Future<void> setCustomCurrencySymbol(String value) async {
    state = state.copyWith(customCurrencySymbol: value);
    await DatabaseService()
        .settingsBox
        .put('custom_currency_symbol', value);
  }

  Future<void> setCurrencyPosition(String value) async {
    state = state.copyWith(currencyPosition: value);
    await DatabaseService().settingsBox.put('currency_position', value);
  }
}
