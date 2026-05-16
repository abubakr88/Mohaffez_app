import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tour_mode_state.dart';
import 'widgets/register_prompt_sheet.dart';

/// Returns `true` and shows the registration prompt when the app is in tour
/// mode. Callers should `return` immediately when this returns `true`.
///
/// Usage:
/// ```dart
/// onPressed: () {
///   if (guardWriteInTour(ref, context)) return;
///   // existing write logic
/// }
/// ```
bool guardWriteInTour(WidgetRef ref, BuildContext context) {
  if (!ref.read(tourModeProvider).active) return false;
  showRegisterPrompt(context);
  return true;
}

/// Same as [guardWriteInTour] but reads the provider container straight from
/// [context]. Use in plain `StatefulWidget`s that don't have a `WidgetRef`.
bool guardWriteInTourCtx(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(tourModeProvider).active) return false;
  showRegisterPrompt(context);
  return true;
}
