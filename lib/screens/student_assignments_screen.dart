// lib/screens/student_assignments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/user_provider.dart';

class StudentAssignmentsScreen extends ConsumerWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('الرجاء تسجيل الدخول')),
          );
        }

        return _AssignmentsContent(studentId: user.uid);
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

class _AssignmentsContent extends ConsumerStatefulWidget {
  final String studentId;

  const _AssignmentsContent({required this.studentId});

  @override
  ConsumerState<_AssignmentsContent> createState() =>
      _AssignmentsContentState();
}

class _AssignmentsContentState extends ConsumerState<_AssignmentsContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync =
        ref.watch(studentSessionsFirstPageProvider(widget.studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Modern App Bar with Tabs
            SliverAppBar(
              expandedHeight: 130,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.accentGreen, Color(0xFF66BB6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 24, 14),
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
                                  Icons.assignment,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'واجباتي',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.accentGreen,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: AppTheme.accentGreen,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.pending_actions, size: 20),
                        text: 'قيد الإنجاز',
                      ),
                      Tab(
                        icon: Icon(Icons.check_circle, size: 20),
                        text: 'مكتملة',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tab Content
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Active Assignments
                  sessionsAsync.when(
                    data: (sessions) {
                      final activeSessions = sessions
                          .where((s) =>
                              (s['status'] as String?) == 'accepted' &&
                              ((s['hifzAssignment'] as String?)?.isNotEmpty ==
                                      true ||
                                  (s['murajaAssignment'] as String?)
                                          ?.isNotEmpty ==
                                      true))
                          .toList();

                      if (activeSessions.isEmpty) {
                        return const EmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'لا توجد واجبات حالية',
                          message: 'ستظهر واجباتك النشطة هنا',
                          animated: true,
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(
                              studentSessionsFirstPageProvider(widget.studentId));
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: activeSessions.length,
                          itemBuilder: (context, index) {
                            return _ActiveAssignmentCard(
                              session: activeSessions[index],
                            );
                          },
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErrorDisplay.dataLoad(
                      onRetry: () => ref.invalidate(
                        studentSessionsFirstPageProvider(widget.studentId),
                      ),
                    ),
                  ),

                  // Completed Assignments
                  sessionsAsync.when(
                    data: (sessions) {
                      final completedSessions = sessions
                          .where((s) => (s['status'] as String?) == 'completed')
                          .toList();

                      if (completedSessions.isEmpty) {
                        return const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'لا توجد واجبات مكتملة',
                          message: 'أكمل واجباتك لتظهر هنا',
                          animated: true,
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: completedSessions.length,
                        itemBuilder: (context, index) {
                          return _CompletedAssignmentCard(
                            session: completedSessions[index],
                            studentId: widget.studentId,
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErrorDisplay.dataLoad(
                      onRetry: () => ref.invalidate(
                        studentSessionsFirstPageProvider(widget.studentId),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ACTIVE ASSIGNMENT CARD
// ============================================================================

class _ActiveAssignmentCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const _ActiveAssignmentCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final mohaffezName = session['mohaffezName'] as String? ?? 'محفظ';
    final hifz = session['hifzAssignment'] as String? ?? '';
    final muraja = session['murajaAssignment'] as String? ?? '';
    final sessionDate = session['sessionDate'] as DateTime?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to session details if needed
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: AppTheme.accentGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mohaffezName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (sessionDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('dd MMM yyyy', 'ar')
                                    .format(sessionDate),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'قيد الإنجاز',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Assignments
              if (hifz.isNotEmpty)
                _AssignmentItem(
                  icon: Icons.book,
                  label: 'حفظ',
                  content: hifz,
                  color: Colors.green,
                ),
              if (hifz.isNotEmpty && muraja.isNotEmpty)
                const SizedBox(height: 12),
              if (muraja.isNotEmpty)
                _AssignmentItem(
                  icon: Icons.refresh,
                  label: 'مراجعة',
                  content: muraja,
                  color: Colors.blue,
                ),
              const SizedBox(height: 16),

              // Progress Indicator
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: Colors.grey.shade200,
                      color: AppTheme.accentGreen,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '60%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPLETED ASSIGNMENT CARD - ✅ UPDATED WITH NEW EVALUATION FEATURES
// ============================================================================

class _CompletedAssignmentCard extends ConsumerWidget {
  final Map<String, dynamic> session;
  final String studentId;

  const _CompletedAssignmentCard({
    required this.session,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mohaffezName = session['mohaffezName'] as String? ?? 'محفظ';
    final hifz = session['hifzAssignment'] as String? ?? '';
    final muraja = session['murajaAssignment'] as String? ?? '';
    final sessionDate = session['sessionDate'] as DateTime?;
    final sessionId = session['id'] as String? ?? '';

    // ✅ NEW: التقييمات
    final previousHifzCompleted = session['previousHifzCompleted'] as bool?;
    final previousHifzRating = session['previousHifzRating'] as int? ?? 0;
    final previousMurajaCompleted =
        session['previousMurajaCompleted'] as bool?;
    final previousMurajaRating = session['previousMurajaRating'] as int? ?? 0;
    final performanceNotes = session['performanceNotes'] as String?;
    final sessionRating = session['sessionRating'] as int? ?? 0;
    final sessionNotes = session['sessionNotes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mohaffezName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (sessionDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy', 'ar').format(sessionDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // ✅ عرض التقييم العام
                if (sessionRating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '$sessionRating/10',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // ✅ تقييم الأداء السابق
            if (previousHifzCompleted != null ||
                previousMurajaCompleted != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.assignment_turned_in,
                      size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'تقييم أدائك في التكليف السابق:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (previousHifzCompleted != null)
                _buildPerformanceBadge(
                  'الحفظ',
                  previousHifzCompleted,
                  previousHifzRating,
                  Colors.green,
                ),

              if (previousMurajaCompleted != null) ...[
                const SizedBox(height: 8),
                _buildPerformanceBadge(
                  'المراجعة',
                  previousMurajaCompleted,
                  previousMurajaRating,
                  Colors.blue,
                ),
              ],

              if (performanceNotes != null && performanceNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ملاحظات على أدائك:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              performanceNotes,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // ✅ التكليف الجديد المعطى
            if (hifz.isNotEmpty || muraja.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.assignment, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'التكليف الجديد للجلسة القادمة:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (hifz.isNotEmpty)
                _CompletedAssignmentItem(
                  icon: Icons.book,
                  label: 'حفظ',
                  content: hifz,
                  color: Colors.green,
                ),
              if (hifz.isNotEmpty && muraja.isNotEmpty)
                const SizedBox(height: 12),
              if (muraja.isNotEmpty)
                _CompletedAssignmentItem(
                  icon: Icons.refresh,
                  label: 'مراجعة',
                  content: muraja,
                  color: Colors.blue,
                ),
            ],

            // ✅ رسالة من المحفظ
            if (sessionNotes != null && sessionNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.message, size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'رسالة من المحفّظ:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sessionNotes,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ✅ دالة مساعدة لعرض شارة الأداء
  Widget _buildPerformanceBadge(
    String label,
    bool completed,
    int rating,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: completed ? color : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          if (completed) ...[
            Expanded(
              child: Row(
                children: [
                  ...List.generate(
                    rating,
                    (index) =>
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$rating/10',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Text(
              'لم يُكمل',
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// ASSIGNMENT ITEM WIDGET (ACTIVE)
// ============================================================================

class _AssignmentItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String content;
  final Color color;

  const _AssignmentItem({
    required this.icon,
    required this.label,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ASSIGNMENT ITEM WIDGET (COMPLETED) - ✅ UPDATED
// ============================================================================

class _CompletedAssignmentItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String content;
  final Color color;

  const _CompletedAssignmentItem({
    required this.icon,
    required this.label,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
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
