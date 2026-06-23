/*
 * ============================================================================
 * Project: Finance me Local
 * Author: BaveSerdem
 * Copyright (c) 2026.
 *
 * LICENSE: Personal Non-Commercial Use Only
 * ============================================================================
 */

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

class UnlockScreen extends StatefulWidget {
  final void Function() onUnlocked;

  const UnlockScreen({super.key, required this.onUnlocked});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _keyService = KeyService();
  final _focusNode = FocusNode();
  bool _obscure = true;
  bool _isLoading = false;
  bool _unlockSuccess = false;
  String? _error;
  bool _biometricAvailable = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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
      _error = null;
    });

    final storedKey = base64Decode(storedKeyB64);
    final storedToken = base64Decode(storedTokenB64);
    final computedToken = KeyService.computeBiometricToken(
      Uint8List.fromList(storedKey),
    );
    if (!_keyService.constantTimeEquals(computedToken, storedToken)) {
      if (mounted) {
        _setError('Biometric data corrupted. Please use your password.');
      }
      return;
    }

    try {
      final db = DatabaseService();
      await db.openBoxes(Uint8List.fromList(storedKey));
      await RecurringService.processDueItems();
      if (mounted) _onUnlockSuccess();
    } catch (e) {
      if (mounted) _setError('An error occurred. Please try again.');
    }
  }

  Future<void> _unlock() async {
    if (_isLoading) return;

    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _error = 'Please enter your password';
      });
      return;
    }

    _focusNode.unfocus();

    setState(() {
      _isLoading = true;
      _error = null;
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
        _setError('Credentials not found. Please reinstall the app.');
        return;
      }

      final salt = base64Decode(storedSaltB64);
      final derivedKey = await _keyService.deriveKey(password, salt);

      final candidate = _keyService.computeVerifier(derivedKey);

      final storedVerifier = base64Decode(storedVerifierB64);

      if (!_keyService.constantTimeEquals(candidate, storedVerifier)) {
        _setError('Incorrect password');
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

      _setError('An error occurred. Please try again.');
      _passwordController.clear();
      _focusNode.requestFocus();
    }
  }

  void _setError(String message) {
    setState(() {
      _error = message;
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
    final t = ProviderScope.containerOf(context).read(stringsProvider);

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
                      'Welcome back',
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
                        labelText: 'Password',
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
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _error != null
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
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
                                        _error!,
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
                                  : const Text('Unlock'),
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
                    // ── Exit ──────────────────────────────────────────
                    TextButton(
                      onPressed: () => SystemNavigator.pop(),
                      child: const Text('Exit App'),
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
