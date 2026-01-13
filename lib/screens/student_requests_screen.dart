// screens/student_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_provider_paginated.dart'; // FIXED IMPORT
import '../providers/user_provider.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/constants/app_theme.dart';

class StudentRequestsScreen extends ConsumerWidget {
  const StudentRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('لم يتم تسجيل الدخول')),
          );
        }
        return _buildContent(context, ref, user.uid);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErrorDisplay.dataLoad(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, String studentId) {
    // FIXED: Use correct provider
    final requestsAsync = ref.watch(studentRequestsFirstPageProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلباتي'),
          elevation: 0,
        ),
        body: requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return const EmptyState(
                icon: Icons.request_page,
                title: 'لا توجد طلبات',
                message: 'لم تقم بإرسال أي طلبات حتى الآن',
                animated: false,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _buildRequestCard(request);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorDisplay.dataLoad(
            // FIXED: Use correct provider
            onRetry: () => ref.invalidate(studentRequestsFirstPageProvider(studentId)),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(dynamic request) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (request.status.toString()) {
      case 'SessionRequestStatus.pending':
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'قيد الانتظار';
        statusIcon = Icons.pending;
        break;
      case 'SessionRequestStatus.accepted':
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'مقبول';
        statusIcon = Icons.check_circle;
        break;
      case 'SessionRequestStatus.rejected':
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'مرفوض';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'غير معروف';
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Mohaffez name
            Text(
              request.mohaffezName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Session type
            Row(
              children: [
                const Icon(Icons.home, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  request.sessionType == 'home' ? 'منزل' : 'مسجد',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            
            // Time slot
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  request.preferredTimeSlot,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
