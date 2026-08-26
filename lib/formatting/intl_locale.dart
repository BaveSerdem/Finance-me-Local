// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

/// Maps the app's language codes onto tags that `package:intl` actually knows.
///
/// The app ships six languages, but `intl` has no date symbols for Kurdish at
/// all — `DateFormat.yMMMd('ku')` throws rather than falling back. Every call
/// into `DateFormat` or `NumberFormat` must therefore go through [intlTagFor].
library;

/// Language codes the app offers, mirroring `LocaleNotifier._allLanguages`.
const _known = {'en', 'ar', 'ru', 'de', 'tr'};

/// Returns the `intl` tag to use for [languageCode].
///
/// Unknown codes — Kurdish included — fall back to English, which is the same
/// choice `MaterialApp` already makes for its own localisations.
String intlTagFor(String languageCode) =>
    _known.contains(languageCode) ? languageCode : 'en';

/// Returns the tag to use for **numbers**.
///
/// Arabic is deliberately mapped to English here while dates stay Arabic.
/// `NumberFormat('ar')` renders Arabic-Indic digits (٠١٢٣) with `٫` and `٬`
/// separators; those glyphs are not covered by `FontFeature.tabularFigures()`,
/// so amounts stop aligning in a column — the one thing a money app cannot
/// afford. Latin digits are also what regional banking apps use.
///
/// Change this single line to `intlTagFor` if Arabic-Indic digits are wanted.
String numberTagFor(String languageCode) =>
    languageCode == 'ar' ? 'en' : intlTagFor(languageCode);
