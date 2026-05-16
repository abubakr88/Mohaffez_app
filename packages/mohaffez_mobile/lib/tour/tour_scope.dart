import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tour_fixtures.dart';
import 'tour_mode_state.dart';
import 'tour_overrides.dart';

/// Wraps [child] with a nested [ProviderScope] that overrides identity and
/// data providers with tour-mode fixtures whenever [tourModeProvider] is
/// active.
///
/// When inactive, returns [child] unchanged so the real Firestore providers
/// stay in effect.
class TourScope extends ConsumerWidget {
  final Widget child;
  const TourScope({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tour = ref.watch(tourModeProvider);
    if (!tour.active || tour.role == null) return child;

    final loader = tour.role == TourRole.student
        ? TourFixtures.loadStudent()
        : TourFixtures.loadTeacher();

    return FutureBuilder<Object>(
      future: loader,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return ProviderScope(
          overrides: buildTourOverrides(tour.role!, snapshot.data!),
          child: child,
        );
      },
    );
  }
}
