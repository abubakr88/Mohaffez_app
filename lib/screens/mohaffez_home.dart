// screens/mohaffez_home.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/constants/app_theme.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/widgets/empty_state.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../shared/utils/error_handler.dart';
import 'pending_requests_screen.dart'; // NEW - Create this screen
import 'completed_sessions_screen.dart'; // NEW - Create this screen
import 'upcoming_sessions_screen.dart';

class MohaffezHome extends ConsumerWidget {
  const MohaffezHome({super.key});

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
        return MohaffezHomeContent(mohaffezId: user.uid);
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

class MohaffezHomeContent extends ConsumerStatefulWidget {
  final String mohaffezId;

  const MohaffezHomeContent({
    super.key,
    required this.mohaffezId,
  });

  @override
  ConsumerState<MohaffezHomeContent> createState() => _MohaffezHomeState();
}

class _MohaffezHomeState extends ConsumerState<MohaffezHomeContent> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section - UPDATED
          _buildWelcomeSection(),
          const SizedBox(height: 24),

          // Quick statistics (clickable cards) - UPDATED
          _buildQuickStats(),
          const SizedBox(height: 24),

          // Upcoming sessions card - UPDATED
          _buildUpcomingSessionsCard(),
          const SizedBox(height: 24),

          // REMOVED: Pending requests preview section
        ],
      ),
    );
  }

  // ==================== Welcome Section - UPDATED ====================
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
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
                  child: Center( // CENTERED
                    child: Text(
                      'مرحباً، ${user.name}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 56), // Balance the icon space
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ==================== Quick Stats - UPDATED ====================
  Widget _buildQuickStats() {
    // CHANGED: Use completed sessions count instead of all sessions
    final completedSessionsAsync = ref.watch(
      completedSessionsCountProvider(widget.mohaffezId),
    );
    final pendingRequestsAsync = ref.watch(
      pendingRequestsFirstPageProvider(widget.mohaffezId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نظرة عامة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Completed Sessions Card - UPDATED
            Expanded(
              child: completedSessionsAsync.when(
                data: (count) => _buildStatCard(
                  icon: Icons.event_available,
                  title: 'الجلسات المكتملة',
                  value: count.toString(),
                  color: AppTheme.accentGreen,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CompletedSessionsScreen(
                          mohaffezId: widget.mohaffezId,
                        ),
                      ),
                    );
                  },
                ),
                loading: () => _buildStatCard(
                  icon: Icons.event_available,
                  title: 'الجلسات المكتملة',
                  value: '...',
                  color: AppTheme.accentGreen,
                  onTap: () {},
                ),
                error: (_, __) => _buildStatCard(
                  icon: Icons.event_available,
                  title: 'الجلسات المكتملة',
                  value: '0',
                  color: AppTheme.accentGreen,
                  onTap: () {},
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Pending Requests Card - UPDATED
            Expanded(
              child: pendingRequestsAsync.when(
                data: (requests) => _buildStatCard(
                  icon: Icons.pending_actions,
                  title: 'الطلبات المعلقة',
                  value: requests.length.toString(),
                  color: Colors.orange,
                  onTap: () {
                    // CHANGED: Navigate to dedicated screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PendingRequestsScreen(
                          mohaffezId: widget.mohaffezId,
                        ),
                      ),
                    );
                  },
                ),
                loading: () => _buildStatCard(
                  icon: Icons.pending_actions,
                  title: 'الطلبات المعلقة',
                  value: '...',
                  color: Colors.orange,
                  onTap: () {},
                ),
                error: (_, __) => _buildStatCard(
                  icon: Icons.pending_actions,
                  title: 'الطلبات المعلقة',
                  value: '0',
                  color: Colors.orange,
                  onTap: () {},
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 32, color: color),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Upcoming Sessions Card - UPDATED ====================
  Widget _buildUpcomingSessionsCard() {
    // CHANGED: Get upcoming sessions for the next 7 days
    final sessionsAsync = ref.watch(
      upcomingSessionsProvider(widget.mohaffezId),
    );

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  color: AppTheme.primaryAmber,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الجلسات القادمة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'خلال الأسبوع القادم', // ADDED: Duration indicator
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // CHANGED: Navigate to upcoming sessions screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UpcomingSessionsScreen(
                          mohaffezId: widget.mohaffezId,
                        ),
                      ),
                    );
                  },
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const Divider(height: 24),
            sessionsAsync.when(
              data: (sessions) => _buildUpcomingSessionsList(sessions),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => ErrorDisplay.dataLoad(
                onRetry: () => ref.invalidate(
                  upcomingSessionsProvider(widget.mohaffezId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSessionsList(List<dynamic> sessions) {
    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy,
        title: 'لا توجد جلسات قادمة',
        message: 'سيتم عرض جلساتك القادمة خلال الأسبوع هنا',
        animated: false,
      );
    }

    return Column(
      children: sessions.take(3).map((session) {
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
              title: Text(session['studentName'] as String? ?? 'غير معروف'),
              subtitle: Text(
                session['sessionDate'] != null  // ✅ Use bracket notation
                  ? '${(session['sessionDate'] as DateTime).day}/${(session['sessionDate'] as DateTime).month} - ${session['preferredTimeSlot'] ?? ""}'
                  : session['preferredTimeSlot'] as String? ?? '',
              ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showAssignmentDialog(session['id!']),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== Actions ====================

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
            title: const Text('إضافة تكليف'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: hifzController,
                    decoration: const InputDecoration(
                      labelText: 'تكليف الحفظ',
                      hintText: 'مثال: من 1 إلى 10',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: murajaController,
                    decoration: const InputDecoration(
                      labelText: 'تكليف المراجعة',
                      hintText: 'مثال: الجزء الأول كاملاً',
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
                      hintText: 'أضف ملاحظاتك هنا...',
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
        ErrorHandler.showSuccess(context, 'تم حفظ التكليف بنجاح');
      }
      ref.invalidate(upcomingSessionsProvider(widget.mohaffezId));
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }
}
