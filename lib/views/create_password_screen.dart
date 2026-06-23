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

import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/key_service.dart';
import '../services/recurring_service.dart';
import '../services/secure_storage_service.dart';
import 'home_screen.dart';

class CreatePasswordScreen extends StatefulWidget {
  const CreatePasswordScreen({super.key});

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _keyService = KeyService();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;
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
      _passwordController.text.length >= 8 &&
      _confirmController.text.length >= 8 &&
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

  Color _strengthColor(int score, ColorScheme cs) {
    switch (score) {
      case 1:
        return cs.error;
      case 2:
        return const Color(0xFFE67E22); // orange
      case 3:
        return const Color(0xFFF1C40F); // amber
      case 4:
        return cs.primary;
      default:
        return cs.surfaceContainerHighest;
    }
  }

  Future<void> _onCreate() async {
    if (!_isValid) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final password = _passwordController.text;
      final salt = _keyService.generateSalt();
      final key = await _keyService.deriveKey(password, salt);

      final db = DatabaseService();
      await db.openBoxes(key);

      await RecurringService.processDueItems();

      final verifier = _keyService.computeVerifier(key);
      final secureStorage = SecureStorageService();
      await secureStorage.savePasswordVerifier(base64Encode(verifier));
      await secureStorage.saveKdfSalt(base64Encode(salt));

      await db.settingsBox.put('has_password', 'true');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        'Create Password',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This password encrypts your data.\nIt cannot be recovered if forgotten.',
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
                          labelText: 'Password',
                          hintText: 'Minimum 8 characters',
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
                          labelText: 'Confirm Password',
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
                          'Passwords do not match',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      // ── Error ─────────────────────────────────────
                      if (_error != null) ...[
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
                                  _error!,
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
                              : const Text('Create & Enter'),
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
