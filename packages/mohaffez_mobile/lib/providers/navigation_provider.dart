import 'package:flutter_riverpod/flutter_riverpod.dart';

// Bottom navigation index
class BottomNavIndexNotifier extends StateNotifier<int> {
  BottomNavIndexNotifier() : super(0);

  void setIndex(int index) {
    state = index;
  }

  void reset() {
    state = 0;
  }
}

final bottomNavIndexProvider =
    StateNotifierProvider<BottomNavIndexNotifier, int>((ref) {
  return BottomNavIndexNotifier();
});
