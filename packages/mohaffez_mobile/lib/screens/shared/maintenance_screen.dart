import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/system_config_provider.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/utils/arabic_labels.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(systemConfigProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
            child: config.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text(ArabicLabels.unexpectedError),
              data: (cfg) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.handyman,
                      size: AppThemeConstants.icon2xl,
                      color: AppThemeConstants.primary),
                  const SizedBox(height: AppThemeConstants.spaceLg),
                  const Text(ArabicLabels.maintenanceTitle,
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppThemeConstants.spaceMd),
                  Text(
                      cfg.maintenanceMessage.isEmpty
                          ? ArabicLabels.maintenanceSubtitle
                          : cfg.maintenanceMessage,
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppThemeConstants.spaceLg),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(systemConfigProvider),
                    child: const Text(ArabicLabels.checkAgain),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
