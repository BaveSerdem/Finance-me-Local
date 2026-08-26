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

/// Swipe-to-delete wrapper with a direction-aware background.
///
/// The two hand-rolled versions this replaces had the same Arabic bug.
/// `DismissDirection.endToStart` **is** direction-aware — in an RTL layout the
/// card slides left-to-right — but they paired it with `Alignment.centerRight`
/// and `EdgeInsets.only(right: 24)`, which are not. So in Arabic the card slid
/// one way while the trash icon stayed pinned to the right edge, ending up
/// underneath the card instead of in the gap it revealed.
///
/// Using `AlignmentDirectional.centerEnd` and `EdgeInsetsDirectional` makes the
/// background follow the swipe in both directions.
///
/// The two copies also disagreed on corner radius — 12 in one, 24 in the other
/// — so two adjacent rows in the same list revealed differently shaped
/// backgrounds. There is one radius here.
class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({
    super.key,
    required this.dismissKey,
    required this.onDismissed,
    required this.child,
  });

  final Key dismissKey;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: AppSpace.xl),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onError),
      ),
      onDismissed: (_) => onDismissed(),
      child: child,
    );
  }
}
