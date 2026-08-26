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

import '../theme/app_metrics.dart';

/// The app's screen frame.
///
/// Collapses two defects that were spread across every pushed screen:
///
/// * **No `SafeArea`.** Analytics, Settings, Security, Customization and
///   Recurring each built a bare `Scaffold` + `ListView`. The `AppBar` covered
///   the status bar, so the top looked fine — but the bottom was unprotected
///   and the last row scrolled under the Android gesture bar. Since the app
///   targets SDK 36, edge-to-edge is enforced and cannot be opted out of, so
///   the inset has to be handled rather than avoided.
///
/// * **A floating action button covering content.** The Recurring screen put a
///   FAB over a list padded with a flat 16, so the last card's pause and delete
///   buttons sat permanently underneath it.
///
/// Both are properties of the frame, not of any one screen, which is why they
/// belong here instead of being fixed five times.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.centerTitle = true,
  });

  final String title;

  /// Typically a scrollable. Bottom padding for the gesture bar — and for the
  /// [floatingActionButton] when present — is applied here, so the child must
  /// not add its own.
  final Widget body;

  final List<Widget>? actions;

  final Widget? floatingActionButton;

  /// Sits beneath the title — a `TabBar`, typically.
  final PreferredSizeWidget? bottom;

  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    // `viewPadding` rather than `padding`: it reports the gesture inset even
    // while the keyboard is open, so a sheet opening does not momentarily
    // collapse the list's bottom clearance.
    final systemInset = MediaQuery.viewPaddingOf(context).bottom;
    final fabClearance = floatingActionButton == null ? 0.0 : 88.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: centerTitle,
        actions: actions,
        bottom: bottom,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        // The bottom inset is added as padding below, not eaten by SafeArea,
        // so content still scrolls through the gesture area instead of ending
        // in a dead band above it.
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: systemInset + fabClearance + AppSpace.sm,
          ),
          child: body,
        ),
      ),
    );
  }
}
