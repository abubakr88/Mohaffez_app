// lib/screens/mohaffez_students_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';

import '../../models/mohaffez_student_summary.dart';
import '../../providers/session_provider_paginated.dart';
import '../../providers/user_provider.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';
import '../../shared/utils/arabic_labels.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Root widget: only resolves the authenticated user.
// The inner _StudentsBody widget owns the students provider watch so that
// ref.watch(mohaffezStudentsProvider) is NEVER called conditionally.
// ─────────────────────────────────────────────────────────────────────────────
class MohaffezStudentsScreen extends ConsumerWidget {
  const MohaffezStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text(ArabicLabels.userNotFound)),
          );
        }
        // FIX: separate widget ensures watch is always at top-level build
        return _StudentsBody(mohaffezId: user.uid);
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

// ─────────────────────────────────────────────────────────────────────────────
// Inner body: watches mohaffezStudentsProvider unconditionally.
// ─────────────────────────────────────────────────────────────────────────────
class _StudentsBody extends ConsumerWidget {
  final String mohaffezId;

  const _StudentsBody({required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FIX: FutureProvider — either resolves to data or transitions to error.
    // Will never stay in AsyncLoading indefinitely.
    final studentsAsync = ref.watch(mohaffezStudentsProvider(mohaffezId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mohaffezStudentsProvider(mohaffezId));
            await ref
                .read(mohaffezStudentsProvider(mohaffezId).future)
                .catchError((_) => <MohaffezStudentSummary>[]);
          },
          child: CustomScrollView(
            slivers: [
              _AppBarSliver(mohaffezId: mohaffezId),
              studentsAsync.when(
                // Show stale data while refreshing instead of re-showing skeleton
                skipLoadingOnRefresh: true,
                data: (students) {
                  if (students.isEmpty) {
                    return const SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.people_outline,
                        title: 'لا يوجد طلاب بعد',
                        message: 'ستظهر هنا قائمة طلابك بعد إجراء أول جلسة',
                        animated: true,
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final student = students[index];
                          return StudentCard(
                            student: student,
                            onTap: () {
                              context.push(
                                '/student/${student.studentId}',
                                extra: student,
                              );
                            },
                          );
                        },
                        childCount: students.length,
                      ),
                    ),
                  );
                },
                // FIX: skeleton cards instead of single full-screen spinner
                loading: () => const SliverFillRemaining(
                  child: _SkeletonList(),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: ErrorDisplay.dataLoad(
                    onRetry: () =>
                        ref.invalidate(mohaffezStudentsProvider(mohaffezId)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SliverAppBar extracted to its own widget
// ─────────────────────────────────────────────────────────────────────────────
class _AppBarSliver extends ConsumerWidget {
  final String mohaffezId;

  const _AppBarSliver({required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppThemeConstants.primary, AppThemeConstants.primaryVariant],
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
                          color: AppThemeConstants.surface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.groups,
                            size: 28, color: AppThemeConstants.onPrimary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'طلابي',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppThemeConstants.onPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'قائمة الطلاب',
                              style: TextStyle(
                                  fontSize: 12, color: AppThemeConstants.onPrimary.withValues(alpha: 0.7)),
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

// ─────────────────────────────────────────────────────────────────────────────
// StudentCard — pure StatelessWidget; session count comes from the model.
// No ConsumerWidget needed — eliminates N+1 provider calls entirely.
// ─────────────────────────────────────────────────────────────────────────────
class StudentCard extends StatelessWidget {
  final MohaffezStudentSummary student;
  final VoidCallback onTap;

  const StudentCard({
    super.key,
    required this.student,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = student.lastSessionDate != null
        ? DateFormat('dd/MM/yyyy', 'ar').format(student.lastSessionDate!)
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        AppThemeConstants.secondary.withValues(alpha: 0.2),
                    child: const Icon(Icons.person,
                        color: AppThemeConstants.secondary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.studentName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Session count chip — pre-aggregated, zero extra queries
                  _StatChip(
                    icon: Icons.school,
                    label: '${student.sessionCount}',
                    color: AppThemeConstants.primary,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey),
                ],
              ),

              const Divider(height: 24),

              // ── Assignments ─────────────────────────────────────────────
              if (student.hifzAssignment.isNotEmpty) ...[
                _AssignmentRow(
                  icon: Icons.menu_book,
                  label: 'حفظ',
                  value: student.hifzAssignment,
                  color: Colors.green,
                ),
                const SizedBox(height: 6),
              ],
              if (student.murajaAssignment.isNotEmpty)
                _AssignmentRow(
                  icon: Icons.refresh,
                  label: 'مراجعة',
                  value: student.murajaAssignment,
                  color: Colors.blue,
                ),

              // ── Rating ──────────────────────────────────────────────────
              if (student.sessionRating > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${student.sessionRating} / 10',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber),
                    ),
                  ],
                ),
              ],

              // ── Previous evaluation ─────────────────────────────────────
              if (student.previousHifzCompleted != null ||
                  student.previousMurajaCompleted != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'الجلسة السابقة:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (student.previousHifzCompleted != null) ...[
                      Icon(
                        student.previousHifzCompleted!
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 14,
                        color: student.previousHifzCompleted!
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'حفظ (${student.previousHifzRating})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (student.previousMurajaCompleted != null) ...[
                      Icon(
                        student.previousMurajaCompleted!
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 14,
                        color: student.previousMurajaCompleted!
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'مراجعة (${student.previousMurajaRating})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],

              // ── Performance notes ───────────────────────────────────────
              if (student.performanceNotes != null &&
                  student.performanceNotes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notes, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          student.performanceNotes!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AssignmentRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loading — 5 ghost cards instead of a single spinner
// ─────────────────────────────────────────────────────────────────────────────
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, __) => _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _Shimmer(
                  child: CircleAvatar(
                      radius: 28, backgroundColor: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Shimmer(
                        child: Container(
                          height: 16,
                          width: 140,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _Shimmer(
                        child: Container(
                          height: 12,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _Shimmer(
                  child: Container(
                    height: 32,
                    width: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Shimmer(
              child: Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _Shimmer(
              child: Container(
                height: 12,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  final Widget child;

  const _Shimmer({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      child: child,
    );
  }
}
