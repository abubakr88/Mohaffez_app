import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TourRole { student, mohaffez }

class TourModeState {
  final bool active;
  final TourRole? role;

  const TourModeState({this.active = false, this.role});

  const TourModeState.inactive() : active = false, role = null;
  const TourModeState.asStudent() : active = true, role = TourRole.student;
  const TourModeState.asMohaffez() : active = true, role = TourRole.mohaffez;
}

class TourModeNotifier extends Notifier<TourModeState> {
  @override
  TourModeState build() => const TourModeState.inactive();

  void enter(TourRole role) {
    state = TourModeState(active: true, role: role);
  }

  void exit() {
    state = const TourModeState.inactive();
  }
}

final tourModeProvider =
    NotifierProvider<TourModeNotifier, TourModeState>(TourModeNotifier.new);
