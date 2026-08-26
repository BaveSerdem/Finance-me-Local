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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_metrics.dart';

/// Wraps a row so a long press offers Edit and Delete.
class LongPressMenuCard extends ConsumerWidget {
  const LongPressMenuCard({
    super.key,
    required this.onEdit,
    required this.onDelete,
    required this.child,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final reduceMotion = ref.watch(reduceMotionProvider);

    return GestureDetector(
      onLongPress: () {
        if (!reduceMotion) HapticFeedback.mediumImpact();
        showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          builder: (sheetContext) {
            final colorScheme = Theme.of(sheetContext).colorScheme;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.edit_outlined,
                        color: colorScheme.primary,
                      ),
                      title: Text(t('edit')),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onEdit();
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: colorScheme.error,
                      ),
                      title: Text(
                        t('delete'),
                        style: TextStyle(color: colorScheme.error),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onDelete();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: child,
    );
  }
}
