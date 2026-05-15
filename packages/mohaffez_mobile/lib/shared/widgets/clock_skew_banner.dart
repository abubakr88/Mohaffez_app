import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

/// Surfaces when the device clock is off by more than the warning threshold.
/// Silent NTP correction keeps the app behaving correctly, but the lock-screen
/// clock will still be wrong — the user needs to know.
class ClockSkewBanner extends ConsumerWidget {
  const ClockSkewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOff = ref.watch(clockSkewWarningProvider);
    if (!isOff) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppThemeConstants.warning,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Row(
        children: [
          Icon(Icons.access_time_filled_rounded,
              color: AppThemeConstants.white, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'ساعة هاتفك غير صحيحة — يرجى تصحيح الوقت من إعدادات الجهاز.',
              style: TextStyle(
                color: AppThemeConstants.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
