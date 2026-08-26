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

/// One choice inside an [AppSegmented].
@immutable
class AppSegment<T> {
  const AppSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// The app's single segmented control.
///
/// Exists to make one specific bug structurally impossible to reintroduce.
///
/// `SegmentedButton.showSelectedIcon` defaults to **true**, so Flutter injects
/// a leading check icon plus its gap — roughly 26 logical pixels — into the
/// selected segment only. Segments are laid out at equal width, so the selected
/// one has to fit `check + gap + label` into the same box its neighbours fill
/// with the label alone. Where the label was wrapped in
/// `FittedBox(fit: BoxFit.scaleDown)` the text obediently shrank, which is why
/// the *selected* tab rendered visibly smaller than the unselected ones — the
/// opposite of what selection should communicate. Where it was not wrapped, the
/// label truncated instead.
///
/// The flag is not themeable: `SegmentedButtonThemeData` exposes only `style`
/// and `selectedIcon`. So it has to be set per widget — and the only reliable
/// way to set it everywhere is to stop constructing `SegmentedButton` directly.
///
/// Labels here are plain [Text] with ellipsis and **never** a `FittedBox`, so
/// every segment renders at the same size at any of the app's three font
/// scales.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<AppSegment<T>> segments;

  final T selected;

  /// Null renders the control read-only — used by the transaction sheet when
  /// the type was already chosen by which summary tile was tapped.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final control = SegmentedButton<T>(
      showSelectedIcon: false,
      segments: [
        for (final segment in segments)
          ButtonSegment<T>(
            value: segment.value,
            label: Text(
              segment.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      selected: {selected},
      onSelectionChanged:
          onChanged == null ? null : (values) => onChanged!(values.first),
    );

    if (onChanged != null) return control;
    return Opacity(opacity: 0.6, child: control);
  }
}
