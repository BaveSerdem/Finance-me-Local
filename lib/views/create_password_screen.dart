// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_palette.dart';
import '../services/database_service.dart';
import '../services/key_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/biometric_enrollment.dart';
import 'home/home_shell.dart';

class CreatePasswordScreen extends ConsumerStatefulWidget {
  const CreatePasswordScreen({super.key});

  @override
  ConsumerState<CreatePasswordScreen> createState() =>
      _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends ConsumerState<CreatePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _keyService = KeyService();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  /// Error *key*, resolved at build time — see the note in `unlock_screen`.
  String? _errorKey;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Gated on reduce-motion for the same reason as the unlock screen: this is
    // the very first screen a new user sees.
    _fadeController = AnimationController(
      vsync: this,
      duration: ref.read(reduceMotionProvider)
          ? Duration.zero
          : const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool get _passwordsMatch =>
      _passwordController.text == _confirmController.text;

  bool get _isValid =>
      _passwordController.text.length >= 6 &&
      _confirmController.text.length >= 6 &&
      _passwordsMatch;

  // ── Password strength: 0–4 ─────────────────────────────────────────

  int _strengthScore(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 10) score++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;\/`~]')
        .hasMatch(password)) {
      score++;
    }
    return score.clamp(0, 4);
  }

  /// The strength ramp.
  ///
  /// Colour is the second channel here, not the only one — the number of
  /// filled bars carries the same information — so this stays readable without
  /// hue. The two middle steps come from the palette rather than raw hex,
  /// which is what makes them legible in light mode.
  Color _strengthColor(int score, ColorScheme cs, AppPalette palette) {
    switch (score) {
      case 1:
        return cs.error;
      case 2:
        return palette.warning;
      case 3:
        return palette.caution;
      case 4:
        return palette.income;
      default:
        return cs.surfaceContainerHighest;
    }
  }

  Future<void> _onCreate() async {
    if (!_isValid) return;

    setState(() {
      _isLoading = true;
      _errorKey = null;
    });

    try {
      final password = _passwordController.text;
      // Fresh derivation every time: a cached key from a previous failed attempt
      // would let the verifier (computed under that key) disagree with a salt
      // we are about to persist under a different password — an unrecoverable
      // vault from the very first setup.
      _keyService.clearCache();
      final salt = _keyService.generateSalt();
      final key = await _keyService.deriveKey(password, salt);

      final db = DatabaseService();
      await db.openBoxes(key);

      // `RecurringService.processDueItems()` used to run here, between opening
      // the boxes and persisting the salt and verifier. If it threw, the boxes
      // were left encrypted under a key whose salt had never been saved — an
      // unrecoverable vault. It also had nothing to do: this is first run, so
      // the subscription box is provably empty.

      final verifier = _keyService.computeVerifier(key);
      final secureStorage = SecureStorageService();
      await secureStorage.savePasswordVerifier(base64Encode(verifier));
      await secureStorage.saveKdfSalt(base64Encode(salt));

      await db.settingsBox.put('has_password', 'true');

      if (!mounted) return;
      await offerBiometricEnrollment(context, ref, key);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      }
    } catch (e) {
      setState(() {
        _errorKey = 'error_try_again';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strength = _strengthScore(_passwordController.text);
    final confirmNotEmpty = _confirmController.text.isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withAlpha(12),
              colorScheme.surface,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Logo ──────────────────────────────────────
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withAlpha(30),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'img/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // ── Title ─────────────────────────────────────
                      Text(
                        t('create_password_title'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t('create_password_warning'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // ── Password field ────────────────────────────
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: t('password'),
                          hintText: t('min_6_characters'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      // ── Strength indicator ────────────────────────
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(4, (i) {
                            final filled = i < strength;
                            return Expanded(
                              child: Padding(
                                padding:
                                    EdgeInsets.only(right: i < 3 ? 6 : 0),
                                child: AnimatedContainer(
                                  duration: const Duration(
                                    milliseconds: 300,
                                  ),
                                  curve: Curves.easeInOut,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(2),
                                    color: filled
                                        ? _strengthColor(
                                            strength,
                                            colorScheme,
                                            context.palette,
                                          )
                                        : colorScheme
                                            .surfaceContainerHighest,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // ── Confirm field ─────────────────────────────
                      TextField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        enabled: !_isLoading,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: t('confirm_password'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: confirmNotEmpty
                              ? Icon(
                                  _passwordsMatch
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _passwordsMatch
                                      ? colorScheme.primary
                                      : colorScheme.error,
                                )
                              : IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () => setState(
                                    () =>
                                        _obscureConfirm =
                                            !_obscureConfirm,
                                  ),
                                ),
                        ),
                      ),
                      if (confirmNotEmpty && !_passwordsMatch) ...[
                        const SizedBox(height: 8),
                        Text(
                          t('passwords_do_not_match'),
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      // ── Error ─────────────────────────────────────
                      if (_errorKey != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  t(_errorKey!),
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // ── Create button ─────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed:
                              _isLoading || !_isValid ? null : _onCreate,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(t('create_and_enter')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
