import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/session_provider_paginated.dart';
import '../shared/constants/app_theme.dart';
import '../shared/utils/error_handler.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';

class PendingRequestsScreen extends ConsumerWidget {
  final String mohaffezId;

  const PendingRequestsScreen({super.key, required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsFirstPageProvider(mohaffezId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Modern App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Color(0xFFFFB74D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.pending_actions,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الطلبات الجديدة',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'قم بمراجعة وقبول الطلبات',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Requests List
            requestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return const SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'لا توجد طلبات جديدة',
                      message: 'ستظهر طلبات الطلاب هنا',
                      animated: true,
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final request = requests[index];
                        return _PendingRequestCard(
                          request: request,
                          mohaffezId: mohaffezId,
                        );
                      },
                      childCount: requests.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: ErrorDisplay.dataLoad(
                  onRetry: () => ref.invalidate(
                    pendingRequestsFirstPageProvider(mohaffezId),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRequestCard extends ConsumerWidget {
  final Map request;
  final String mohaffezId;

  const _PendingRequestCard({
    required this.request,
    required this.mohaffezId,
  });

  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentName = request['studentName'] as String? ?? 'طالب';
    final sessionType = request['sessionType'] as String? ?? '';
    final timeSlot = request['preferredTimeSlot'] as String? ?? '08:00';
    final location = request['imamAddressText'] as String?;

    final slotStart = _asDateTime(request['slotStart']);
    final createdAt = _asDateTime(request['createdAt']);
    final displayDate = slotStart ?? createdAt;

    final dateText = displayDate != null
        ? DateFormat('EEEE dd/MM/yyyy', 'ar').format(displayDate)
        : 'غير محدد';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Info
            Row(
              children: [
                Hero(
                  tag: 'student_${request['id']}',
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryAmber.withOpacity(0.2),
                    child: const Icon(
                      Icons.person,
                      color: AppTheme.primaryAmber,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'طلب جديد',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // Request Details
            _DetailItem(
              icon: _getSessionTypeIcon(sessionType),
              label: 'نوع الجلسة',
              value: _getSessionTypeLabel(sessionType),
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _DetailItem(
              icon: Icons.calendar_today,
              label: 'اليوم',
              value: dateText,
              color: Colors.purple,
            ),
            const SizedBox(height: 12),
            _DetailItem(
              icon: Icons.access_time,
              label: 'الوقت المفضل',
              value: timeSlot,
              color: Colors.green,
            ),
            if (location?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              _DetailItem(
                icon: Icons.location_on,
                label: 'الموقع',
                value: location!,
                color: Colors.red,
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectRequest(context, ref, request['id']),
                    icon: const Icon(Icons.close, size: 20),
                    label: const Text('رفض'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red, width: 2),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptRequest(context, ref, request['id']),
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('قبول الطلب'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptRequest(
    BuildContext context,
    WidgetRef ref,
    String? requestId,
  ) async {
    if (requestId == null) return;

    try {
      await ref
          .read(sessionActionsProvider.notifier)
          .acceptRequestAndCreateSession(requestId);

      if (!context.mounted) return;

      ErrorHandler.showSuccess(context, 'تم قبول الطلب وإنشاء الجلسة');
      ref.invalidate(pendingRequestsFirstPageProvider(mohaffezId));
      ref.invalidate(upcomingSessionsProvider(mohaffezId));
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    WidgetRef ref,
    String? requestId,
  ) async {
    if (requestId == null) return;

    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => const _RejectReasonDialog(),
    );

    // Cancelled
    if (reason == null) return;

    final sanitizedReason = reason.trim().isEmpty ? null : reason.trim();

    try {
      await ref
          .read(sessionActionsProvider.notifier)
          .rejectRequest(requestId, sanitizedReason);

      if (!context.mounted) return;

      ErrorHandler.showSuccess(context, 'تم رفض الطلب');
      ref.invalidate(pendingRequestsFirstPageProvider(mohaffezId));
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }

  IconData _getSessionTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'mosque':
        return Icons.mosque;
      case 'online':
        return Icons.videocam;
      default:
        return Icons.location_on;
    }
  }

  String _getSessionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return 'في المنزل';
      case 'mosque':
        return 'في المسجد';
      case 'online':
        return 'عن بُعد';
      default:
        return type;
    }
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final reasonController = TextEditingController();

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اختياري: يمكنك توضيح سبب الرفض',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, reasonController.text.trim()),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
  }
}
