import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

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
          color: Colors.red.shade600,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لا يوجد اتصال بالإنترنت، سيتم مزامنة البيانات عند العودة.',
                  style: const TextStyle(
                    color: Colors.white,
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
