/*
 * ============================================================================
 * Project: Finance me Local
 * Author: BaveSerdem
 * Copyright (c) 2026.
 *
 * LICENSE: Personal Non-Commercial Use Only
 * You may download, compile, and use this application for personal, private use.
 * Redistribution, modification for commercial purposes, selling, or monetizing
 * this code, in whole or in part, is strictly prohibited without explicit
 * written permission from the author.
 * ============================================================================
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'providers/theme_provider.dart';
import 'providers/customization_provider.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/secure_storage_service.dart';
import 'localization/locale_provider.dart';
import 'views/create_password_screen.dart';
import 'views/eula_screen.dart';
import 'views/home_screen.dart';
import 'views/unlock_screen.dart';

void main() async {
  try {
    FlutterCryptography.enable();
    WidgetsFlutterBinding.ensureInitialized();

    await DatabaseService().initialize();

    await NotificationService().initialize();

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
        reduceAnimations: settings.reduceAnimations,
        accentColorHex: customization.accentColorHex,
        amoledMode: customization.amoledMode,
        fontSize: customization.fontSize,
      ),
      darkTheme: buildThemeData(
        brightness: Brightness.dark,
        colorPalette: settings.colorPalette,
        reduceAnimations: settings.reduceAnimations,
        accentColorHex: customization.accentColorHex,
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

    if (!hasPassword) {
      return _buildFirstRunFlow();
    }

    final reduceAnimations = ref.watch(themeProvider).reduceAnimations;

    return AnimatedSwitcher(
      duration: reduceAnimations ? Duration.zero : const Duration(milliseconds: 300),
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

  Widget _buildFirstRunFlow() {
    return FutureBuilder<bool>(
      future: _eulaFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.done)) {
          return const CreatePasswordScreen();
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const CreatePasswordScreen();
        }
        return EulaScreen(onAccepted: () => setState(() {
          _eulaFuture = SecureStorageService().isEulaAccepted();
        }));
      },
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
          return const HomeScreen();
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const HomeScreen();
        }
        return EulaScreen(onAccepted: () => setState(() {
          _eulaFuture = SecureStorageService().isEulaAccepted();
        }));
      },
    );
  }
}

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
                            borderRadius: BorderRadius.circular(12),
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
                            borderRadius: BorderRadius.circular(12),
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
