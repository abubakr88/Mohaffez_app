import 'package:flutter/material.dart';
import 'package:mohaffez_core/src/services/connectivity_service.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.connectionStream,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        if (isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          color: AppThemeConstants.error,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: const Row(
            children: [
              Icon(Icons.wifi_off, color: AppThemeConstants.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لا يوجد اتصال بالإنترنت، سيتم مزامنة البيانات عند العودة.',
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
      },
    );
  }
}
