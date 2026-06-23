import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import 'app_strings.dart';

class LocaleNotifier extends Notifier<Locale> {
  static const _languageKey = 'app_language';
  static const _allLanguages = ['en', 'ar', 'ru', 'de', 'ku', 'tr'];

  @override
  Locale build() {
    _loadFromStorage();
    return const Locale('en');
  }

  DatabaseService get _db => DatabaseService();

  Future<void> _loadFromStorage() async {
    final lang = _db.settingsBox.get(_languageKey);
    if (lang != null && lang.isNotEmpty && _allLanguages.contains(lang)) {
      state = Locale(lang);
    }
  }

  Future<void> setLocale(String languageCode) async {
    if (!_allLanguages.contains(languageCode)) return;
    state = Locale(languageCode);
    await _db.settingsBox.put(_languageKey, languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

final stringsProvider = Provider<String Function(String)>((ref) {
  final locale = ref.watch(localeProvider);
  return (key) => AppStrings.get(key, locale.languageCode);
});
