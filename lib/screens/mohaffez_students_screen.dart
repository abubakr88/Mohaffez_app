import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/user_provider.dart';
import '../utils/arabic_labels.dart';

class MohaffezStudentsScreen extends ConsumerWidget {
  const MohaffezStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(
              child: Text(ArabicLabels.userNotFound),
            ),
          );
        }

        final studentsAsync = ref.watch(mohaffezStudentsProvider(user.uid));

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                _buildAppBar(context, ref, user.uid),
                studentsAsync.when(
                  data: (students) {
                    if (students.isEmpty) {
                      return const SliverFillRemaining(
                        child: EmptyState(
                          icon: Icons.people_outline,
                          title: 'لا يوجد طلاب',
                          message: 'لم تقم بتدريس أي طالب بعد',
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final student = students[index];
                            return StudentCard(
                              student: student,
                              mohaffezId: user.uid,
                            );
                          },
                          childCount: students.length,
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => SliverFillRemaining(
                    child: ErrorDisplay.dataLoad(
                      onRetry: () =>
                          ref.invalidate(mohaffezStudentsProvider(user.uid)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: ErrorDisplay.dataLoad(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref, String mohaffezId) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(mohaffezStudentsProvider(mohaffezId)),
          tooltip: ArabicLabels.refresh,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
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
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.groups,
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
                              'طلابي',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'قائمة الطلاب الذين تدرسهم',
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
    );
  }
}

// Student Card Widget

class StudentCard extends ConsumerWidget {
  final Map student;
  final String mohaffezId;

  const StudentCard({
    super.key,
    required this.student,
    required this.mohaffezId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentName =
        student['studentName'] as String? ?? ArabicLabels.student;
    final lastSessionDate = student['lastSessionDate'] as DateTime?;
    final hifzAssignment = student['hifzAssignment'] as String? ?? '';
    final murajaAssignment = student['murajaAssignment'] as String? ?? '';
    final sessionRating = student['sessionRating'] as int? ?? 0;
    final status = student['status'] as String? ?? 'accepted';

    // Evaluation fields
    final previousHifzCompleted = student['previousHifzCompleted'] as bool?;
    final previousHifzRating = student['previousHifzRating'] as int? ?? 0;
    final previousMurajaCompleted = student['previousMurajaCompleted'] as bool?;
    final previousMurajaRating = student['previousMurajaRating'] as int? ?? 0;
    final performanceNotes = student['performanceNotes'] as String?;

    final sessionCountAsync = ref.watch(
      studentSessionCountProvider({
        'mohaffezId': mohaffezId,
        'studentId': student['studentId'] as String,
      }),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to detailed student screen if needed
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
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        AppTheme.accentGreen.withValues(alpha: 0.2),
                    child: const Icon(
                      Icons.person,
                      color: AppTheme.accentGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lastSessionDate != null
                                  ? DateFormat('dd MMM yyyy', 'ar')
                                      .format(lastSessionDate)
                                  : 'لا توجد جلسات',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: status == 'completed'
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status == 'completed' ? 'مكتملة' : 'مقبولة',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: status == 'completed'
                                      ? Colors.green.shade700
                                      : Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  sessionCountAsync.when(
                    data: (count) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.book, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '$count جلسة',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),

              // Evaluation Section (if completed)
              if (status == 'completed' &&
                  (previousHifzCompleted != null ||
                      previousMurajaCompleted != null)) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تقييم الأداء',
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
                if (performanceNotes != null &&
                    performanceNotes.isNotEmpty) ...[
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
                          child: Text(
                            performanceNotes,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              // Current Assignments (if status is accepted)
              if (status == 'accepted' &&
                  (hifzAssignment.isNotEmpty ||
                      murajaAssignment.isNotEmpty)) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.assignment,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'الواجبات الحالية',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (hifzAssignment.isNotEmpty)
                  _buildAssignmentItem(
                    Icons.book,
                    'الحفظ',
                    hifzAssignment,
                    Colors.green,
                  ),
                if (hifzAssignment.isNotEmpty && murajaAssignment.isNotEmpty)
                  const SizedBox(height: 8),
                if (murajaAssignment.isNotEmpty)
                  _buildAssignmentItem(
                    Icons.refresh,
                    'المراجعة',
                    murajaAssignment,
                    Colors.blue,
                  ),
              ],

              // Session Rating
              if (sessionRating > 0) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.star, size: 20, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      '$sessionRating/10',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceBadge(
    String label,
    bool completed,
    int rating,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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
              'غير مكتمل',
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

  Widget _buildAssignmentItem(
    IconData icon,
    String label,
    String content,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
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
