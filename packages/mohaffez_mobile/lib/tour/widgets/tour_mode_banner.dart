import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../config/app_router.dart';
import '../tour_mode_state.dart';

/// Slim persistent banner shown at the top of the screen whenever the user
/// is browsing in tour mode.
class TourModeBanner extends ConsumerWidget {
  const TourModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tour = ref.watch(tourModeProvider);
    if (!tour.active) return const SizedBox.shrink();

    return Material(
      color: AppThemeConstants.secondary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.visibility_outlined,
                  size: 18, color: AppThemeConstants.onPrimary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'وضع التجربة — سجّل لحفظ بياناتك',
                  style: TextStyle(
                    color: AppThemeConstants.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(tourModeProvider.notifier).exit();
                  ref.read(goRouterProvider).go('/login');
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppThemeConstants.onPrimary,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text(
                  'خروج',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
