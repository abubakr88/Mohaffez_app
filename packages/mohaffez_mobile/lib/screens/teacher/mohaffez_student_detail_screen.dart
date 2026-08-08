// lib/screens/mohaffez_student_detail_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../shared/widgets/empty_state.dart';
import '../../shared/utils/time_formatter.dart';
import '../../shared/widgets/error_widgets.dart';
import 'teacher_active_bundle_card.dart';

const _studentDetailSessionLimit = 5;
const _studentDetailSessionCacheDuration = Duration(minutes: 5);

// Provider: latest sessions between this teacher and this specific student.
final studentDetailSessionsProvider = FutureProvider.autoDispose.family<
    List<Map<String, dynamic>>,
    ({
      String mohaffezId,
      String studentId,
      String? studentProfileId
    })>((ref, p) async {
  Query<Map<String, dynamic>> query = FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('mohaffezId', isEqualTo: p.mohaffezId)
      .where('studentId', isEqualTo: p.studentId);

  final profileId = p.studentProfileId?.trim();
  if (profileId != null && profileId.isNotEmpty && profileId != 'self') {
    query = query.where('studentProfileId', isEqualTo: profileId);
  }

  final snapshot = await query
      .orderBy('sessionDate', descending: true)
      .limit(_studentDetailSessionLimit)
      .get()
      .timeout(const Duration(seconds: 15));

  // Cache successful results briefly so reopening the same student does not
  // immediately repeat the read. Pull-to-refresh still fetches fresh data.
  final cacheLink = ref.keepAlive();
  final cacheTimer = Timer(
    _studentDetailSessionCacheDuration,
    cacheLink.close,
  );
  ref.onDispose(cacheTimer.cancel);

  return snapshot.docs.map((doc) {
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
    // mohaffezId may be empty when the route builder ran in the outer
    // ProviderScope (e.g. tour mode). Fall back to the in-scope current user.
    final effectiveMohaffezId = mohaffezId.isNotEmpty
        ? mohaffezId
        : (ref.watch(currentUserProvider).value?.uid ?? '');
    final params = (
      mohaffezId: effectiveMohaffezId,
      studentId: student.studentId,
      studentProfileId: student.studentProfileId,
    );
    final sessionsAsync = ref.watch(studentDetailSessionsProvider(params));
    final challengeV2Enabled =
        ref.watch(systemConfigProvider).valueOrNull?.challengeV2Enabled ?? true;
    final bundlesAsync = effectiveMohaffezId.isEmpty
        ? const AsyncValue<List<TeacherActiveBundleInfo>>.data([])
        : ref.watch(teacherActiveBundlesProvider(effectiveMohaffezId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(studentDetailSessionsProvider(params));
            if (effectiveMohaffezId.isNotEmpty) {
              ref.invalidate(
                teacherActiveBundlesProvider(effectiveMohaffezId),
              );
            }
            await ref
                .read(studentDetailSessionsProvider(params).future)
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
                        colors: [
                          AppThemeConstants.primary,
                          AppThemeConstants.primaryVariant
                        ],
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

              // ── Action buttons ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: challengeV2Enabled
                              ? () => context.push(
                                    '/student-challenges',
                                    extra: {
                                      'mohaffezId': effectiveMohaffezId,
                                      'studentId': student.studentId,
                                      'studentProfileId':
                                          student.studentProfileId,
                                      'studentName': student.studentName,
                                      'sessions':
                                          sessionsAsync.valueOrNull ?? const [],
                                    },
                                  )
                              : null,
                          icon: const Icon(Icons.extension_rounded, size: 18),
                          label: const Text('التحديات'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppThemeConstants.primary,
                            side: const BorderSide(
                                color: AppThemeConstants.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MarkSurahButton(
                          studentId: student.studentId,
                          studentName: student.studentName,
                          studentProfileId: student.studentProfileId,
                          mohaffezId: mohaffezId,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Session list ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: _StudentActiveBundlesSection(
                  student: student,
                  bundlesAsync: bundlesAsync,
                  onRetry: effectiveMohaffezId.isEmpty
                      ? null
                      : () => ref.invalidate(
                            teacherActiveBundlesProvider(effectiveMohaffezId),
                          ),
                ),
              ),

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
                                    if (student.sessionCount >
                                        _studentDetailSessionLimit) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppThemeConstants.warning
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'آخر 5',
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
                        ref.invalidate(studentDetailSessionsProvider(params)),
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

class _StudentActiveBundlesSection extends StatelessWidget {
  const _StudentActiveBundlesSection({
    required this.student,
    required this.bundlesAsync,
    this.onRetry,
  });

  final MohaffezStudentSummary student;
  final AsyncValue<List<TeacherActiveBundleInfo>> bundlesAsync;
  final VoidCallback? onRetry;

  bool _belongsToStudent(TeacherActiveBundleInfo bundle) {
    if (bundle.studentId != student.studentId) return false;

    final studentProfileId = student.studentProfileId?.trim() ?? '';
    final bundleProfileId = bundle.studentProfileId?.trim() ?? '';
    final hasSpecificProfile =
        studentProfileId.isNotEmpty && studentProfileId != 'self';

    if (hasSpecificProfile) {
      if (bundleProfileId.isNotEmpty) {
        return bundleProfileId == studentProfileId;
      }
      return bundle.learnerName.trim() == student.studentName.trim();
    }

    return bundleProfileId.isEmpty ||
        bundleProfileId == 'self' ||
        bundle.learnerName.trim() == student.studentName.trim();
  }

  @override
  Widget build(BuildContext context) {
    return bundlesAsync.when(
      data: (bundles) {
        final studentBundles = bundles.where(_belongsToStudent).toList();
        if (studentBundles.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الباقات النشطة (${studentBundles.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              for (final bundle in studentBundles) ...[
                TeacherActiveBundleCard(
                  bundle: bundle,
                  compact: true,
                  onTap: () => showTeacherBundleDetails(context, bundle),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('تعذر تحميل الباقات النشطة - إعادة المحاولة'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            fontSize: 14,
                            color: AppThemeConstants.textSecondary),
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
                  fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
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
    final formattedDate =
        date != null ? DateFormat('dd/MM/yyyy', 'ar').format(date) : '—';

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    formatTimeToArabicAmPm(
                        session['preferredTimeSlot'] as String? ?? ''),
                    style: const TextStyle(
                        fontSize: 13, color: AppThemeConstants.black87),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.category,
                      size: 14, color: AppThemeConstants.grey500),
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

// ─── Mark surah button ────────────────────────────────────────────────────────
class _MarkSurahButton extends ConsumerWidget {
  final String studentId;
  final String studentName;
  final String? studentProfileId;
  final String mohaffezId;

  const _MarkSurahButton({
    required this.studentId,
    required this.studentName,
    this.studentProfileId,
    required this.mohaffezId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahsAsync = ref.watch(learnerMemorizedSurahsProvider(
      (studentId: studentId, studentProfileId: studentProfileId),
    ));
    final memorized = surahsAsync.valueOrNull?.toSet() ?? {};

    return OutlinedButton.icon(
      onPressed: () => _showSurahSheet(context, ref, memorized),
      icon: const Icon(Icons.military_tech_rounded, size: 18),
      label: Text('سور (${memorized.length})'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFB7791F),
        side: const BorderSide(color: Color(0xFFD4A44A)),
        backgroundColor: const Color(0xFFFFFBEB),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _showSurahSheet(
    BuildContext context,
    WidgetRef ref,
    Set<int> memorized,
  ) {
    final mohaffezAsync = ref.read(currentUserProvider);
    final mohaffezName = mohaffezAsync.valueOrNull?.name ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SurahMarkSheet(
        studentId: studentId,
        studentName: studentName,
        studentProfileId: studentProfileId,
        mohaffezId: mohaffezId,
        mohaffezName: mohaffezName,
        memorized: memorized,
      ),
    );
  }
}

// ─── Surah mark bottom sheet ──────────────────────────────────────────────────
class _SurahMarkSheet extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;
  final String? studentProfileId;
  final String mohaffezId;
  final String mohaffezName;
  final Set<int> memorized;

  const _SurahMarkSheet({
    required this.studentId,
    required this.studentName,
    this.studentProfileId,
    required this.mohaffezId,
    required this.mohaffezName,
    required this.memorized,
  });

  @override
  ConsumerState<_SurahMarkSheet> createState() => _SurahMarkSheetState();
}

class _SurahMarkSheetState extends ConsumerState<_SurahMarkSheet> {
  late Set<int> _memorized;
  String _search = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _memorized = Set.from(widget.memorized);
  }

  Future<void> _toggle(int surahNum) async {
    final wasMemorized = _memorized.contains(surahNum);
    setState(() {
      if (wasMemorized) {
        _memorized.remove(surahNum);
      } else {
        _memorized.add(surahNum);
      }
      _busy = true;
    });
    try {
      await toggleMemorizedSurah(
        studentId: widget.studentId,
        studentProfileId: widget.studentProfileId,
        surahNumber: surahNum,
        isCurrentlyMemorized: wasMemorized,
        mohaffezId: widget.mohaffezId,
        mohaffezName: widget.mohaffezName,
      );
    } catch (e) {
      // revert on error
      setState(() {
        if (wasMemorized) {
          _memorized.add(surahNum);
        } else {
          _memorized.remove(surahNum);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ. يرجى المحاولة مرة أخرى'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter surahs by search
    final filtered = List.generate(114, (i) => i + 1).where((n) {
      if (_search.isEmpty) return true;
      return surahNames[n - 1].contains(_search) || '$n'.contains(_search);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.military_tech_rounded,
                        color: Color(0xFFB7791F)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'السور المحفوظة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            widget.studentName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                const Color(0xFFD4A44A).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '${_memorized.length} / 114',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB7791F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن سورة...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5EDE9)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5EDE9)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF4F7F6),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),

              // List
              Expanded(
                child: AbsorbPointer(
                  absorbing: _busy,
                  child: ListView.builder(
                    controller: controller,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final num = filtered[i];
                      final name = surahNames[num - 1];
                      final done = _memorized.contains(num);
                      return ListTile(
                        onTap: () => _toggle(num),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: done
                              ? const Color(0xFFFFF8E1)
                              : const Color(0xFFF4F7F6),
                          child: Text(
                            '$num',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: done
                                  ? const Color(0xFFB7791F)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight:
                                done ? FontWeight.w800 : FontWeight.w500,
                            color: done
                                ? const Color(0xFF095752)
                                : const Color(0xFF111827),
                          ),
                        ),
                        trailing: done
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFFD4A44A))
                            : Icon(Icons.radio_button_unchecked_rounded,
                                color: Colors.grey[300]),
                      );
                    },
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
