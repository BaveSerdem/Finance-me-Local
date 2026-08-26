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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/biometric_service.dart';
import '../services/database_service.dart';
import '../services/key_service.dart';
import '../services/recurring_service.dart';
import '../services/secure_storage_service.dart';
import '../localization/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_metrics.dart';
import '../widgets/change_password_flow.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  final void Function() onUnlocked;

  const UnlockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _keyService = KeyService();
  final _focusNode = FocusNode();
  bool _obscure = true;
  bool _isLoading = false;
  bool _unlockSuccess = false;

  /// The *key* of the current error, not its text.
  ///
  /// Holding the resolved sentence would freeze it in whatever language was
  /// active when it was raised; the key is resolved in `build`, so an error
  /// already on screen follows a language change like everything else.
  String? _errorKey;
  bool _biometricAvailable = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // The entry fade is the first animation a user meets, and it ran at a fixed
    // 500ms regardless of the reduce-motion setting — which is exactly the
    // audience most likely to have that setting on. The status listener below
    // still fires at zero duration, so the unlock hand-off is unaffected.
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
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _unlockSuccess) {
        widget.onUnlocked();
      }
    });
    _initScreen();
  }

  Future<void> _initScreen() async {
    final storage = SecureStorageService();
    final bioEnabled = await storage.isBiometricEnabled();
    if (!mounted) return;

    _fadeController.forward();

    if (bioEnabled) {
      final bioService = BiometricService(secureStorage: storage);
      final available = await bioService.isBiometricAvailable();
      if (mounted) {
        setState(() => _biometricAvailable = available);
      }
      await _tryBiometric();
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final storage = SecureStorageService();
    final biometricEnabled = await storage.isBiometricEnabled();
    if (!biometricEnabled || !mounted) return;

    final storedTokenB64 = await storage.getBiometricToken();
    final storedKeyB64 = await storage.getBiometricKeyData();
    if (storedTokenB64 == null || storedKeyB64 == null || !mounted) return;

    final biometric = BiometricService(secureStorage: storage);
    final authenticated = await biometric.authenticate();
    if (!authenticated || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorKey = null;
    });

    final storedKey = base64Decode(storedKeyB64);
    final storedToken = base64Decode(storedTokenB64);
    final computedToken = KeyService.computeBiometricToken(
      Uint8List.fromList(storedKey),
    );
    if (!_keyService.constantTimeEquals(computedToken, storedToken)) {
      if (mounted) {
        _setError('biometric_data_corrupted');
      }
      return;
    }

    try {
      final db = DatabaseService();
      await db.openBoxes(Uint8List.fromList(storedKey));
      await RecurringService.processDueItems();
      if (mounted) _onUnlockSuccess();
    } catch (e) {
      if (mounted) _setError('error_try_again');
    }
  }

  Future<void> _unlock() async {
    if (_isLoading) return;

    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _errorKey = 'enter_your_password';
      });
      return;
    }

    _focusNode.unfocus();

    setState(() {
      _isLoading = true;
      _errorKey = null;
    });

    if (!mounted) return;
    await _unlockWithPassword(password);
  }

  Future<void> _unlockWithPassword(String password) async {
    if (password.isEmpty) return;

    try {
      final db = DatabaseService();
      final secureStorage = SecureStorageService();

      final storedVerifierB64 = await secureStorage.getPasswordVerifier();
      final storedSaltB64 = await secureStorage.getKdfSalt();

      if (storedVerifierB64 == null || storedSaltB64 == null) {
        _setError('credentials_not_found');
        return;
      }

      // Never let a stale cached key from a previous (possibly wrong) attempt
      // short-circuit verification. Each unlock attempt must derive fresh from
      // the password actually typed.
      _keyService.clearCache();
      final salt = base64Decode(storedSaltB64);
      final derivedKey = await _keyService.deriveKey(password, salt);

      final candidate = _keyService.computeVerifier(derivedKey);

      final storedVerifier = base64Decode(storedVerifierB64);

      if (!_keyService.constantTimeEquals(candidate, storedVerifier)) {
        _setError('incorrect_password');
        return;
      }

      await db.openBoxes(derivedKey);

      await RecurringService.processDueItems();

      final biometricEnabled = await secureStorage.isBiometricEnabled();
      if (biometricEnabled) {
        final token = KeyService.computeBiometricToken(derivedKey);
        await secureStorage.saveBiometricToken(token);
        await secureStorage.saveBiometricKeyData(derivedKey);
      }

      if (mounted) {
        _onUnlockSuccess();
      }
    } catch (e) {
      if (!mounted) return;

      _setError('error_try_again');
      _passwordController.clear();
      _focusNode.requestFocus();
    }
  }

  void _setError(String key) {
    setState(() {
      _errorKey = key;
      _isLoading = false;
    });
  }

  void _onUnlockSuccess() {
    setState(() {
      _isLoading = false;
      _unlockSuccess = true;
    });
    if (_fadeController.isDismissed) {
      // Screen wasn't fully visible yet (e.g. biometric auto-unlock).
      widget.onUnlocked();
    } else {
      _fadeController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final t = ref.watch(stringsProvider);

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
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Logo ──────────────────────────────────────────
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
                    // ── App name ──────────────────────────────────────
                    Text(
                      'Finance me Local',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('welcome_back'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 36),
                    // ── Password field ────────────────────────────────
                    TextField(
                      controller: _passwordController,
                      focusNode: _focusNode,
                      obscureText: _obscure,
                      autofocus: true,
                      enabled: !_isLoading && !_unlockSuccess,
                      onSubmitted: (_) => _unlock(),
                      decoration: InputDecoration(
                        labelText: t('password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    // ── Biometric retry ───────────────────────────────
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: (_isLoading || _unlockSuccess)
                            ? null
                            : _tryBiometric,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primaryContainer,
                          ),
                          child: Icon(
                            Icons.fingerprint,
                            size: 28,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // ── Error ─────────────────────────────────────────
                    AnimatedSize(
                      duration: ref.watch(reduceMotionProvider)
                          ? Duration.zero
                          : const Duration(milliseconds: AppMotion.base),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _errorKey != null
                          ? Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpace.sm,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.lg,
                                  vertical: AppSpace.md,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
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
                                          color:
                                              colorScheme.onErrorContainer,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    // ── Unlock button ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: FilledButton(
                          onPressed: (_isLoading || _unlockSuccess)
                              ? null
                              : _unlock,
                          child: _unlockSuccess
                              ? const Icon(Icons.check, size: 28)
                              : _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(t('unlock')),
                        ),
                      ),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 12),
                      Text(
                        t('unlocking'),
                        style: TextStyle(
                          color: colorScheme.onSurface.withAlpha(150),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // ── Change password (encrypted mode only) ────────
                    if (DatabaseService().getEncryptionChoice() == true) ...[
                      TextButton(
                        onPressed: () async {
                          await showChangePasswordFlow(
                            context,
                            ref,
                            boxesAlreadyOpen: false,
                          );
                          if (mounted) _passwordController.clear();
                        },
                        child: Text(t('change_password_from_lock_screen')),
                      ),
                    ],
                    // ── Exit ──────────────────────────────────────────
                    TextButton(
                      onPressed: () => SystemNavigator.pop(),
                      child: Text(t('exit_app')),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
