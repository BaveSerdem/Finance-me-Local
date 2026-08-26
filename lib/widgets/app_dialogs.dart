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

/// Asks the user to confirm something destructive.
///
/// Replaces the hand-rolled `AlertDialog` + `TextButton(cancel)` +
/// `FilledButton(styleFrom(backgroundColor: colorScheme.error))` block that
/// appeared in four places with four slightly different button styles.
///
/// Returns `true` only if the user confirmed. The caller performs the action
/// **after** the dialog closes, which is the important difference from the
/// previous versions: those ran the deletion inside `onPressed` and then popped,
/// so a failure left the dialog closed with only a snack bar to explain it, and
/// the `BuildContext` used afterwards belonged to a route already being torn
/// down.
Future<bool> showDestructiveConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final colorScheme = Theme.of(context).colorScheme;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Asks the user to confirm a non-destructive action.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Prompts for a new password and its confirmation.
///
/// Returns the entered password, or `null` if the user cancelled.
///
/// Replaces two hand-built `Form` + two `TextFormField` dialogs — one for
/// changing the vault password, one for setting a backup password — which
/// differed only in their minimum length and their labels. Both leaked their
/// `TextEditingController`s on the cancel path; this disposes in a `finally`.
Future<String?> showNewPasswordDialog(
  BuildContext context, {
  required String title,
  required String passwordLabel,
  required String confirmLabel,
  required String submitLabel,
  required String cancelLabel,
  required String requiredMessage,
  required String mismatchMessage,
  int minLength = 1,
  String? tooShortMessage,
}) async {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  try {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(labelText: passwordLabel),
                validator: (value) {
                  if (value == null || value.isEmpty) return requiredMessage;
                  if (value.length < minLength) {
                    return tooShortMessage ?? requiredMessage;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(labelText: confirmLabel),
                validator: (value) =>
                    value != passwordController.text ? mismatchMessage : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: Text(submitLabel),
          ),
        ],
      ),
    );

    return (accepted ?? false) ? passwordController.text : null;
  } finally {
    passwordController.dispose();
    confirmController.dispose();
  }
}

/// Prompts for the vault password.
///
/// Returns the entered password, or `null` if the user cancelled.
///
/// Replaces four near-identical dialogs that each rebuilt the same
/// `StatefulBuilder` + local `isEmpty` bookkeeping to keep the confirm button
/// disabled until something was typed. Here a `ValueNotifier` does that without
/// a `StatefulBuilder`, and the field submits on the keyboard's action key —
/// which none of the originals supported.
Future<String?> showPasswordPromptDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  required String cancelLabel,
  String? message,
}) async {
  final controller = TextEditingController();
  final isEmpty = ValueNotifier<bool>(true);
  controller.addListener(() => isEmpty.value = controller.text.isEmpty);

  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          if (controller.text.isEmpty) return;
          Navigator.of(dialogContext).pop(controller.text);
        }

        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message != null) ...[
                Text(message),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(labelText: label),
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(cancelLabel),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isEmpty,
              builder: (context, empty, _) => FilledButton(
                onPressed: empty ? null : submit,
                child: Text(confirmLabel),
              ),
            ),
          ],
        );
      },
    );
  } finally {
    controller.dispose();
    isEmpty.dispose();
  }
}
