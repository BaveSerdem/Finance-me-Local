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
import '../services/database_service.dart';
import 'app_strings.dart';

/// Every language the app offers, paired with its own endonym.
///
/// Single source of truth. The Settings dropdown used to hardcode its own list
/// of six `DropdownMenuItem`s alongside `LocaleNotifier._allLanguages`; the two
/// could drift apart with no compile error and no translation warning.
///
/// Names are deliberately **not** translated — a language picker shows each
/// language in that language, so a user who cannot read the current one can
/// still find theirs.
const supportedLanguages = <String, String>{
  'en': 'English',
  'ar': 'العربية',
  'ru': 'Русский',
  'de': 'Deutsch',
  'ku': 'Kurdî',
  'tr': 'Türkçe',
};

class LocaleNotifier extends Notifier<Locale> {
  static const _languageKey = 'app_language';
  static final _allLanguages = supportedLanguages.keys.toList();

  @override
  Locale build() {
    final lang = DatabaseService().settingsBox.get(_languageKey);
    if (lang != null && lang.isNotEmpty && _allLanguages.contains(lang)) {
      return Locale(lang);
    }
    return const Locale('en');
  }

  Future<void> setLocale(String languageCode) async {
    if (!_allLanguages.contains(languageCode)) return;
    state = Locale(languageCode);
    await DatabaseService().settingsBox.put(_languageKey, languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

final stringsProvider = Provider<String Function(String)>((ref) {
  final locale = ref.watch(localeProvider);
  return (key) => AppStrings.get(key, locale.languageCode);
});

/// Parameterised lookup — `tf('key', {'name': 'Netflix'})`.
///
/// Separate from [stringsProvider] rather than folded into it as an optional
/// argument, so the common case stays a one-argument call and the rare case is
/// visibly different at a glance.
final stringsFormatProvider =
    Provider<String Function(String, Map<String, String>)>((ref) {
  final locale = ref.watch(localeProvider);
  return (key, params) => AppStrings.format(key, locale.languageCode, params);
});
