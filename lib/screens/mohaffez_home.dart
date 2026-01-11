// lib/screens/mohaffez_home.dart (FIXED)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider.dart';
import '../providers/session_provider_paginated.dart'; // ADD THIS
import '../shared/utils/error_handler.dart';

class MohaffezHome extends ConsumerWidget {
  const MohaffezHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('يرجى تسجيل الدخول')),
          );
        }
        return _MohaffezHomeContent(mohaffezId: user.uid);
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
}

class _MohaffezHomeContent extends ConsumerStatefulWidget {
  final String mohaffezId;

  const _MohaffezHomeContent({required this.mohaffezId});

  @override
  ConsumerState<_MohaffezHomeContent> createState() => _MohaffezHomeState();
}

class _MohaffezHomeState extends ConsumerState<_MohaffezHomeContent> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section
          _buildWelcomeSection(),
          const SizedBox(height: 24),

          // Statistics cards
          _buildStatisticsSection(),
          const SizedBox(height: 24),

          // Pending requests section
          Text(
            'طلبات الحجز المعلقة',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          _buildPendingRequests(),

          const SizedBox(height: 24),

          // Upcoming sessions section
          Text(
            'الجلسات القادمة',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          _buildUpcomingSessions(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.waving_hand,
                  size: 40,
                  color: Colors.white,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرحباً، ${user.name}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'لديك طلبات جديدة تنتظر الموافقة',
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
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatisticsSection() {
    // FIXED: Use correct provider
    final sessionCountAsync = ref.watch(
      mohaffezSessionCountProvider(widget.mohaffezId),
    );

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.event_available,
            title: 'الجلسات المكتملة',
            value: sessionCountAsync.when(
              data: (count) => count.toString(),
              loading: () => '...',
              error: (_, __) => '0',
            ),
            color: AppTheme.accentGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.pending_actions,
            title: 'الطلبات المعلقة',
            value: _getPendingRequestsCount(),
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  String _getPendingRequestsCount() {
    // FIXED: Use paginated provider
    final requestsAsync = ref.watch(
      paginatedPendingRequestsProvider(widget.mohaffezId),
    );
    return requestsAsync.items.length.toString();
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequests() {
    // FIXED: Use paginated provider
    final firstPageAsync = ref.watch(
      pendingRequestsFirstPageProvider(widget.mohaffezId),
    );

    return firstPageAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لا توجد طلبات معلقة',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: requests.take(3).map((request) {
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
                title: Text(request.studentName),
                subtitle: Text(
                  '${request.sessionType} - ${request.preferredTimeSlot}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _acceptRequest(request.id!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _rejectRequest(request.id!),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorDisplay.dataLoad(
        onRetry: () => ref.invalidate(
          pendingRequestsFirstPageProvider(widget.mohaffezId),
        ),
      ),
    );
  }

  Widget _buildUpcomingSessions() {
    final sessionsAsync = ref.watch(
      upcomingSessionsProvider(widget.mohaffezId),
    );

    return sessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لا توجد جلسات قادمة',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: sessions.map((session) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.accentGreen.withOpacity(0.2),
                  child: const Icon(
                    Icons.school,
                    color: AppTheme.accentGreen,
                  ),
                ),
                title: Text(session.studentName),
                subtitle: Text(
                  session.sessionDate != null
                      ? '${session.sessionDate!.day}/${session.sessionDate!.month} - ${session.preferredTimeSlot ?? ''}'
                      : session.preferredTimeSlot ?? '',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showAssignmentDialog(session.id!),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorDisplay.dataLoad(
        onRetry: () => ref.invalidate(
          upcomingSessionsProvider(widget.mohaffezId),
        ),
      ),
    );
  }

  // FIXED: Use sessionActionsProvider instead of sessionBookingProvider
  Future<void> _acceptRequest(String requestId) async {
    try {
      await ref.read(sessionActionsProvider.notifier).acceptRequest(requestId);
      
      if (mounted) {
        ErrorHandler.showSuccess(context, 'تم قبول الطلب بنجاح');
        // Refresh the list
        ref.invalidate(pendingRequestsFirstPageProvider(widget.mohaffezId));
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'فشل قبول الطلب: $e');
      }
    }
  }

  // FIXED: Use sessionActionsProvider instead of sessionBookingProvider
  Future<void> _rejectRequest(String requestId) async {
    try {
      await ref.read(sessionActionsProvider.notifier).rejectRequest(requestId);
      
      if (mounted) {
        ErrorHandler.showSuccess(context, 'تم رفض الطلب');
        // Refresh the list
        ref.invalidate(pendingRequestsFirstPageProvider(widget.mohaffezId));
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'فشل رفض الطلب: $e');
      }
    }
  }

  void _showAssignmentDialog(String sessionId) {
    final hifzController = TextEditingController();
    final murajaController = TextEditingController();
    int rating = 0;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تحديث معلومات الجلسة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: hifzController,
                    decoration: const InputDecoration(
                      labelText: 'الحفظ',
                      hintText: 'مثال: من آية 1 إلى 10 من سورة البقرة',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: murajaController,
                    decoration: const InputDecoration(
                      labelText: 'المراجعة',
                      hintText: 'مثال: سورة آل عمران كاملة',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  const Text('التقييم:'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(10, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() => rating = index + 1);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                      hintText: 'أضف ملاحظات إضافية...',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _updateAssignment(
                    sessionId: sessionId,
                    hifz: hifzController.text.trim(),
                    muraja: murajaController.text.trim(),
                    rating: rating,
                    notes: notesController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FIXED: Use sessionActionsProvider
  Future<void> _updateAssignment({
    required String sessionId,
    required String hifz,
    required String muraja,
    required int rating,
    required String notes,
  }) async {
    try {
      await ref.read(sessionActionsProvider.notifier).updateAssignment(
            sessionId: sessionId,
            hifzAssignment: hifz,
            murajaAssignment: muraja,
            rating: rating,
            notes: notes,
          );

      if (mounted) {
        ErrorHandler.showSuccess(context, 'تم تحديث معلومات الجلسة بنجاح');
        // Refresh sessions
        ref.invalidate(upcomingSessionsProvider(widget.mohaffezId));
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'فشل تحديث الجلسة: $e');
      }
    }
  }
}
