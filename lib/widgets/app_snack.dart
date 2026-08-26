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

/// How a snack bar reads.
enum SnackKind { neutral, success, error }

/// Shows a transient message.
///
/// Replaces 80 hand-built `SnackBar`s, every one of which repeated
/// `behavior: SnackBarBehavior.floating` and most of which formatted their
/// error text differently.
///
/// Safe to call after an `await`: it checks `context.mounted` itself, which the
/// call sites had to remember to do individually.
void showAppSnack(
  BuildContext context,
  String message, {
  SnackKind kind = SnackKind.neutral,
}) {
  if (!context.mounted) return;

  final colorScheme = Theme.of(context).colorScheme;
  final (background, foreground) = switch (kind) {
    SnackKind.error => (colorScheme.errorContainer, colorScheme.onErrorContainer),
    SnackKind.success => (colorScheme.secondaryContainer, colorScheme.onSecondaryContainer),
    SnackKind.neutral => (colorScheme.inverseSurface, colorScheme.onInverseSurface),
  };

  // Only the colour is set here. `behavior`, `shape` and the inset now come
  // from `snackBarTheme`, so this widget carries just the one thing that is
  // genuinely per-call: which of the three meanings the message has.
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: foreground)),
        backgroundColor: background,
      ),
    );
}

/// Reports a failure.
///
/// [context] first so it reads like [showAppSnack]; [error] is appended only
/// when supplied, so callers can pass a translated sentence on its own rather
/// than leaking an exception's `toString()` at the user.
void showErrorSnack(BuildContext context, String message, [Object? error]) {
  showAppSnack(
    context,
    error == null ? message : '$message: $error',
    kind: SnackKind.error,
  );
}
