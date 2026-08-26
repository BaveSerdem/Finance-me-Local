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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/theme_provider.dart';
import 'providers/customization_provider.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/recurring_service.dart';
import 'services/secure_storage_service.dart';
import 'localization/locale_provider.dart';
import 'views/create_password_screen.dart';
import 'views/encryption_choice_screen.dart';
import 'views/eula_screen.dart';
import 'views/home/home_shell.dart';
import 'views/unlock_screen.dart';

void main() async {
  try {
    // Deprecated — the plugin registers itself now — but deliberately kept.
    // This is the native accelerator behind the PBKDF2 that unlocks a live
    // user's vault; the pure-Dart fallback derives the identical key, so the
    // only thing at stake is speed, and that is not worth trading for silencing
    // one analyzer hint on a shipped encrypted app. Remove it when the symbol
    // actually goes away.
    // ignore: deprecated_member_use
    FlutterCryptography.enable();
    WidgetsFlutterBinding.ensureInitialized();

    // Loads date symbols for every locale. Without this, the moment a
    // `DateFormat` is given a locale tag it throws `LocaleDataException` — so
    // this must run before anything formats a date. Called with no argument
    // deliberately: per-locale initialisation would have to be repeated on
    // every runtime language change.
    await initializeDateFormatting();

    await DatabaseService().initialize();

    await NotificationService().initialize();

    // Android 13+ gates notifications behind a runtime permission. Without this
    // the plugin initialises fine but the POST_NOTIFICATIONS permission stays
    // denied and every scheduled reminder is silently dropped.
    await NotificationService().requestPermissions();

    runApp(const ProviderScope(child: LocalVaultApp()));
  } catch (e, stackTrace) {
    runApp(ErrorApp(error: e.toString(), stackTrace: stackTrace.toString()));
  }
}

class LocalVaultApp extends ConsumerWidget {
  const LocalVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeProvider);
    final customization = ref.watch(customizationProvider);
    final locale = ref.watch(localeProvider);
    final reduceMotion = ref.watch(reduceMotionProvider);

    // Kurdish is deliberately absent from this list and from `supportedLocales`
    // below. `GlobalMaterialLocalizations` ships no `ku` delegate, so handing
    // Material a `Locale('ku')` throws at startup rather than falling back.
    //
    // This is **not** an oversight to be "fixed" by adding `Locale('ku')`:
    // `ku` is fully translated in `AppStrings` and every string the app itself
    // draws is Kurdish. Only the labels Material owns — the date picker's
    // buttons, the text-selection menu — fall back to English, and
    // `intlTagFor` maps `ku → en` so `intl` date formatting does not throw
    // either.
    const materialSupported = ['en', 'ar', 'ru', 'de', 'tr'];
    final materialLocale = materialSupported.contains(locale.languageCode)
        ? locale
        : const Locale('en');

    return MaterialApp(
      title: 'Finance me Local',
      debugShowCheckedModeBanner: false,
      locale: materialLocale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('ru'),
        Locale('de'),
        Locale('tr'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: settings.themeMode,
      theme: buildThemeData(
        brightness: Brightness.light,
        colorPalette: settings.colorPalette,
        reduceAnimations: reduceMotion,
        accentColorHex: customization.accentColorHex,
        bgColorHex: customization.bgColor,
        amoledMode: customization.amoledMode,
        fontSize: customization.fontSize,
      ),
      darkTheme: buildThemeData(
        brightness: Brightness.dark,
        colorPalette: settings.colorPalette,
        reduceAnimations: reduceMotion,
        accentColorHex: customization.accentColorHex,
        bgColorHex: customization.bgColor,
        amoledMode: customization.amoledMode,
        fontSize: customization.fontSize,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _isUnlocked = false;
  late Future<bool> _eulaFuture;
  Future<void>? _unencryptedOpenFuture;

  @override
  void initState() {
    super.initState();
    _eulaFuture = SecureStorageService().isEulaAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    if (!db.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasPassword = db.settingsBox.get('has_password') == 'true';

    // Encrypted path: a password exists (pre-existing user, or a first-run user
    // who chose encryption and created one). Show unlock unless already open.
    if (hasPassword) {
      final reduceMotion = ref.watch(reduceMotionProvider);

      return AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _isUnlocked
            ? _buildPostUnlock(key: const ValueKey('home'))
            : UnlockScreen(
                key: const ValueKey('unlock'),
                onUnlocked: () => setState(() => _isUnlocked = true),
              ),
      );
    }

    // No password. Route on the persisted encryption choice:
    // - opted out → straight to home, no password, no unlock, ever.
    // - not yet decided (first launch) or encryption chosen → first-run flow.
    if (db.getEncryptionChoice() == false) {
      return _buildUnencryptedFlow();
    }
    return _buildFirstRunFlow();
  }

  /// Unencrypted path: open the (unencrypted) boxes directly and go to home.
  /// Also gated by the EULA like every first-run screen.
  Widget _buildUnencryptedFlow() {
    return FutureBuilder<bool>(
      future: _eulaFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.done)) {
          return _buildOpenThenHome();
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return _buildOpenThenHome();
        }
        return EulaScreen(onAccepted: () => setState(() {
          _eulaFuture = SecureStorageService().isEulaAccepted();
        }));
      },
    );
  }

  /// Opens the unencrypted boxes (no cipher is used when the choice is false)
  /// and only then shows the home shell.
  Widget _buildOpenThenHome() {
    final db = DatabaseService();
    _unencryptedOpenFuture ??= () async {
      await db.openBoxes(Uint8List(0));
      // Mirror the encrypted unlock paths (unlock_screen.dart:135, :197):
      // recurring items must be processed once the boxes are open, or an
      // opted-out user's subscriptions and fixed income would never reach the
      // balance. A failure here must never block the home screen.
      try {
        await RecurringService.processDueItems();
      } catch (e) {
        debugPrint('AuthWrapper: recurring processing failed: $e');
      }
    }();
    return FutureBuilder<void>(
      future: _unencryptedOpenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Failed to open data storage'),
            ),
          );
        }
        return const HomeShell();
      },
    );
  }

  Widget _buildFirstRunFlow() {
    return FutureBuilder<bool>(
      future: _eulaFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.done)) {
          return _buildEncryptionOrPassword();
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return _buildEncryptionOrPassword();
        }
        return EulaScreen(onAccepted: () => setState(() {
          _eulaFuture = SecureStorageService().isEulaAccepted();
        }));
      },
    );
  }

  /// After the EULA: encryption choice screen (first launch) or password
  /// creation (encryption already chosen). Opting out routes to home instead.
  Widget _buildEncryptionOrPassword() {
    final choice = DatabaseService().getEncryptionChoice();
    if (choice == false) {
      return _buildUnencryptedFlow();
    }
    if (choice == true) {
      return const CreatePasswordScreen();
    }
    return EncryptionChoiceScreen(
      onEncryptionEnabled: () => setState(() {}),
      onSkipped: () => setState(() {}),
    );
  }

  Widget _buildPostUnlock({Key? key}) {
    return FutureBuilder<bool>(
      key: key,
      future: _eulaFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.done)) {
          return const HomeShell();
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const HomeShell();
        }
        return EulaScreen(onAccepted: () => setState(() {
          _eulaFuture = SecureStorageService().isEulaAccepted();
        }));
      },
    );
  }
}

/// Last-resort screen shown when `main()` itself fails.
///
/// Its colours are hardcoded **on purpose**, and must stay that way. This is
/// what renders when `DatabaseService.initialize()` throws — which is precisely
/// the case where the settings box holding the theme could not be opened, so
/// `buildThemeData` has nothing to read and `Theme.of` would hand back
/// Material's defaults at best. Any token, palette or provider referenced here
/// is a second failure on top of the one being reported.
///
/// The radii match `AppRadius.lg` / `.md` by value rather than by import, for
/// the same reason.
class ErrorApp extends StatelessWidget {
  final String error;
  final String stackTrace;

  const ErrorApp({super.key, required this.error, required this.stackTrace});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xFFE74C3C),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Initialization Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please share this screen with the developer.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE74C3C).withAlpha(80),
                            ),
                          ),
                          child: SelectableText(
                            error,
                            style: const TextStyle(
                              color: Color(0xFFE74C3C),
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(
                            stackTrace,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => SystemNavigator.pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Close App'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
