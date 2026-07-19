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
class TourScope extends ConsumerStatefulWidget {
  final Widget child;
  const TourScope({super.key, required this.child});

  @override
  ConsumerState<TourScope> createState() => _TourScopeState();
}

class _TourScopeState extends ConsumerState<TourScope> {
  TourRole? _cachedRole;
  List<Override>? _cachedOverrides;

  List<Override> _overridesFor(TourRole role) {
    if (_cachedRole == role && _cachedOverrides != null) {
      return _cachedOverrides!;
    }

    final fixture = role == TourRole.student
        ? TourFixtures.loadStudent()
        : TourFixtures.loadTeacher();
    _cachedRole = role;
    _cachedOverrides = List.unmodifiable(buildTourOverrides(role, fixture));
    return _cachedOverrides!;
  }

  @override
  Widget build(BuildContext context) {
    final tour = ref.watch(tourModeProvider);
    if (!tour.active || tour.role == null) return widget.child;

    return ProviderScope(
      key: ValueKey(tour.role),
      overrides: _overridesFor(tour.role!),
      child: widget.child,
    );
  }
}
