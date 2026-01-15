// screens/pending_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/constants/app_theme.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/widgets/empty_state.dart';
import '../providers/session_provider_paginated.dart';
import '../shared/utils/error_handler.dart';

class PendingRequestsScreen extends ConsumerWidget {
  final String mohaffezId;

  const PendingRequestsScreen({
    super.key,
    required this.mohaffezId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(
      pendingRequestsFirstPageProvider(mohaffezId),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الطلبات المعلقة'),
        ),
        body: requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'لا توجد طلبات معلقة',
                message: 'سيتم عرض طلبات الجلسات الجديدة هنا',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryAmber.withOpacity(0.2),
                      child: const Icon(
                        Icons.person,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                    title: Text(request['studentName'] as String? ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${request.sessionType} - ${request.preferredTimeSlot}'),
                        if (request.imamAddressText != null)
                          Text(
                            request.imamAddressText!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _acceptRequest(context, ref, request.id!),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _rejectRequest(context, ref, request.id!),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(
              pendingRequestsFirstPageProvider(mohaffezId),
            ),
          ),
        ),
      ),
    );
  }

  // في ملف lib/screens/pending_requests_screen.dart
  Future<void> _acceptRequest(BuildContext context, WidgetRef ref, String requestId) async {
    try {
      // ✅ FIXED: Use the new method that creates a session
      await ref.read(sessionActionsProvider.notifier).acceptRequestAndCreateSession(requestId);
      
      if (context.mounted) {
        ErrorHandler.showSuccess(context, 'تم قبول الطلب وإنشاء الجلسة بنجاح');
      }
      
      // Refresh both providers
      ref.invalidate(pendingRequestsFirstPageProvider(mohaffezId));
      ref.invalidate(upcomingSessionsProvider(mohaffezId));
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }

  Future<void> _rejectRequest(BuildContext context, WidgetRef ref, String requestId) async {
    try {
      await ref.read(sessionActionsProvider.notifier).rejectRequest(requestId);
      if (context.mounted) {
        ErrorHandler.showSuccess(context, 'تم رفض الطلب');
      }
      ref.invalidate(pendingRequestsFirstPageProvider(mohaffezId));
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }
}
