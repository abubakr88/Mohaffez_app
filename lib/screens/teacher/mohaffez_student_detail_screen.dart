// lib/screens/mohaffez_student_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../models/mohaffez_student_summary.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';

// Provider: all sessions between this teacher and this specific student
final _studentDetailSessionsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>,
        ({String mohaffezId, String studentId})>((ref, p) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('mohaffezId', isEqualTo: p.mohaffezId)
      .where('studentId', isEqualTo: p.studentId)
      .limit(50)
      .get()
      .timeout(const Duration(seconds: 15));

  final docs = snapshot.docs
    ..sort((a, b) {
      final aDate =
          (a.data()['sessionDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      final bDate =
          (b.data()['sessionDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      return bDate.compareTo(aDate);
    });

  return docs.map((doc) {
    final data = doc.data();
    return <String, dynamic>{
      ...data,
      'id': doc.id,
      'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
    };
  }).toList();
});

class MohaffezStudentDetailScreen extends ConsumerWidget {
  final MohaffezStudentSummary student;
  final String mohaffezId;

  const MohaffezStudentDetailScreen({
    super.key,
    required this.student,
    required this.mohaffezId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (mohaffezId: mohaffezId, studentId: student.studentId);
    final sessionsAsync = ref.watch(_studentDetailSessionsProvider(params));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_studentDetailSessionsProvider(params));
            await ref
                .read(_studentDetailSessionsProvider(params).future)
                .catchError((_) => <Map<String, dynamic>>[]);
          },
          child: CustomScrollView(
            slivers: [
              // ── AppBar ─────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 80,
                floating: true,
                pinned: true,
                automaticallyImplyLeading: false,
                title: Text(student.studentName),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppThemeConstants.primary, AppThemeConstants.primaryVariant],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Student summary card ───────────────────────────────────
              SliverToBoxAdapter(
                child: _StudentSummaryCard(student: student),
              ),

              // ── Manage challenges button ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/student-challenges',
                      extra: {
                        'mohaffezId': mohaffezId,
                        'studentId': student.studentId,
                        'studentName': student.studentName,
                      },
                    ),
                    icon: const Icon(Icons.extension_rounded, size: 18),
                    label: const Text('إدارة تحديات الجلسة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemeConstants.primary,
                      side: const BorderSide(color: AppThemeConstants.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),

              // ── Session list ───────────────────────────────────────────
              sessionsAsync.when(
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return const SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.history,
                        title: 'لا توجد جلسات',
                        message: 'لا توجد جلسات مسجلة مع هذا الطالب',
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, index) {
                          if (index == 0) {
                            // Header row before first session
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'سجل الجلسات (${sessions.length})',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (student.sessionCount > 50) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppThemeConstants.warning.withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'آخر 50',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppThemeConstants.warning,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _SessionHistoryCard(session: sessions[index]),
                              ],
                            );
                          }
                          return _SessionHistoryCard(session: sessions[index]);
                        },
                        childCount: sessions.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: ErrorDisplay.dataLoad(
                    onRetry: () =>
                        ref.invalidate(_studentDetailSessionsProvider(params)),
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

class _StudentSummaryCard extends StatelessWidget {
  final MohaffezStudentSummary student;

  const _StudentSummaryCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor:
                      AppThemeConstants.secondary.withValues(alpha: 0.2),
                  child: const Icon(Icons.person,
                      color: AppThemeConstants.secondary, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.studentName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${student.sessionCount} جلسة',
                        style: const TextStyle(
                            fontSize: 14, color: AppThemeConstants.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (student.hifzAssignment.isNotEmpty ||
                student.murajaAssignment.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'الواجب الحالي',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.grey500),
              ),
              const SizedBox(height: 8),
              if (student.hifzAssignment.isNotEmpty)
                _InfoRow(
                  icon: Icons.menu_book,
                  color: AppThemeConstants.success,
                  label: 'حفظ',
                  value: student.hifzAssignment,
                ),
              if (student.murajaAssignment.isNotEmpty)
                _InfoRow(
                  icon: Icons.refresh,
                  color: AppThemeConstants.accentBlue,
                  label: 'مراجعة',
                  value: student.murajaAssignment,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color)),
          Expanded(
              child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _SessionHistoryCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const _SessionHistoryCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final date = session['sessionDate'] as DateTime?;
    final formattedDate = date != null
        ? DateFormat('dd/MM/yyyy', 'ar').format(date)
        : '—';

    final status = session['status'] as String? ?? 'accepted';
    final (statusColor, statusLabel) = switch (status) {
      'completed' => (AppThemeConstants.success, 'مكتملة'),
      'accepted' => (AppThemeConstants.accentBlue, 'مقبولة'),
      'pending' => (AppThemeConstants.warning, 'قيد الانتظار'),
      'rejected' || 'cancelled' => (AppThemeConstants.error, 'ملغية'),
      _ => (AppThemeConstants.grey500, status),
    };

    final hifz = session['hifzAssignment'] as String? ?? '';
    final muraja = session['murajaAssignment'] as String? ?? '';
    final rating = session['sessionRating'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date + status
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: AppThemeConstants.grey500),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            // Time slot
            if (session['preferredTimeSlot'] != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: AppThemeConstants.grey500),
                  const SizedBox(width: 6),
                  Text(
                    session['preferredTimeSlot'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: AppThemeConstants.black87),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.category, size: 14, color: AppThemeConstants.grey500),
                  const SizedBox(width: 4),
                  Text(
                    switch (session['sessionType'] as String? ?? '') {
                      'home' => 'بيت الطالب',
                      'mosque' => 'المسجد',
                      'online' => 'أونلاين',
                      _ => session['sessionType'] as String? ?? '',
                    },
                    style: const TextStyle(
                        fontSize: 13, color: AppThemeConstants.black87),
                  ),
                ],
              ),
            ],

            // Hifz / Muraja assignments for this session
            if (hifz.isNotEmpty || muraja.isNotEmpty) ...[
              const Divider(height: 16),
              if (hifz.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.menu_book,
                        size: 14, color: AppThemeConstants.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'حفظ: $hifz',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (muraja.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.refresh,
                        size: 14, color: AppThemeConstants.accentBlue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'مراجعة: $muraja',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],

            // Rating
            if (rating > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 2,
                runSpacing: 4,
                children: [
                  ...List.generate(
                    10,
                    (i) => Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      size: 12,
                      color: AppThemeConstants.accentAmber,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$rating/10',
                    style: const TextStyle(
                        fontSize: 12, color: AppThemeConstants.grey500),
                  ),
                ],
              ),
            ],

            // Performance notes
            if ((session['performanceNotes'] as String?)?.isNotEmpty ==
                true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppThemeConstants.grey100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session['performanceNotes'] as String? ?? '',
                  style: const TextStyle(
                      fontSize: 12, color: AppThemeConstants.black87),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
