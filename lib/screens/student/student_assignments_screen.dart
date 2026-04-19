// lib/screens/student_assignments_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';
import '../../providers/session_provider_paginated.dart';
import '../../providers/user_provider.dart';
import '../../shared/utils/arabic_labels.dart';
import '../../models/quran_mistake_model.dart';
import '../../shared/utils/quran_mistake_utils.dart';

class StudentAssignmentsScreen extends ConsumerWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text(ArabicLabels.pleaseLoginFirst)),
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

class _AssignmentsContentState extends ConsumerState<_AssignmentsContent> {

  Future<void> _refreshAssignments() async {
    ref.invalidate(studentSessionsFirstPageProvider(widget.studentId));
    await ref
        .read(studentSessionsFirstPageProvider(widget.studentId).future)
        .catchError((_) => <Map<String, dynamic>>[]);
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync =
        ref.watch(studentSessionsFirstPageProvider(widget.studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refreshAssignments,
          child: CustomScrollView(
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
                        colors: [AppThemeConstants.primary, AppThemeConstants.primaryVariant],
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
                                    color: AppThemeConstants.onPrimary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.assignment,
                                    size: 28,
                                    color: AppThemeConstants.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    ArabicLabels.myAssignments,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppThemeConstants.onPrimary,
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
              ),

              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: sessionsAsync.when(
                  data: (sessions) {
                    final completedSessions = sessions
                        .where((s) => (s['status'] as String?) == 'completed')
                        .toList();

                    if (completedSessions.isEmpty) {
                      return const SliverFillRemaining(
                        child: EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: ArabicLabels.noCompletedAssignments,
                          message: ArabicLabels.completeAssignmentsToAppear,
                          animated: true,
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _CompletedAssignmentCard(
                            session: completedSessions[index],
                            studentId: widget.studentId,
                          );
                        },
                        childCount: completedSessions.length,
                      ),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    child: ErrorDisplay.dataLoad(
                      onRetry: () => ref.invalidate(
                        studentSessionsFirstPageProvider(widget.studentId),
                      ),
                    ),
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

// ============================================================================
  // COMPLETED ASSIGNMENT CARD
// ============================================================================

class _CompletedAssignmentCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> session;
  final String studentId;

  const _CompletedAssignmentCard({
    required this.session,
    required this.studentId,
  });

  @override
  ConsumerState<_CompletedAssignmentCard> createState() =>
      _CompletedAssignmentCardState();
}

class _CompletedAssignmentCardState
    extends ConsumerState<_CompletedAssignmentCard> {
  late Map<String, dynamic> session;

  @override
  void initState() {
    super.initState();
    session = widget.session;
  }

  Future<void> _navigateToRating() async {
    final sessionId = session['id'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ في تحميل بيانات الجلسة'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
      return;
    }

    final mohaffezName = session['mohaffezName'] as String? ?? ArabicLabels.mohaffez;
    final result = await context.push<int>(
      '/rate-session/$sessionId?mohaffezName=${Uri.encodeComponent(mohaffezName)}',
    );

    if (result != null && result > 0 && mounted) {
      // Immediately show the real rating without waiting for the provider re-fetch
      setState(() => session = {...session, 'teacherRating': result});
      ref.invalidate(studentSessionsFirstPageProvider(widget.studentId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التقييم بنجاح! شكراً لك'),
          backgroundColor: AppThemeConstants.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mohaffezName =
        session['mohaffezName'] as String? ?? ArabicLabels.mohaffez;
    final hifz = session['hifzAssignment'] as String? ?? '';
    final muraja = session['murajaAssignment'] as String? ?? '';
    // FIX: Firestore stores dates as Timestamp, convert to DateTime
    final sessionDateRaw = session['sessionDate'];
    final sessionDate = sessionDateRaw is Timestamp
        ? sessionDateRaw.toDate()
        : sessionDateRaw as DateTime?;

    // Evaluation values
    final previousHifzCompleted = session['previousHifzCompleted'] as bool?;
    final previousHifzRating = session['previousHifzRating'] as int? ?? 0;
    final previousMurajaCompleted = session['previousMurajaCompleted'] as bool?;
    final previousMurajaRating = session['previousMurajaRating'] as int? ?? 0;
    final performanceNotes = session['performanceNotes'] as String?;
    final teacherRating = session['teacherRating'] as int? ?? 0;
    final sessionNotes = session['sessionNotes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: AppThemeConstants.elevationSm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppThemeConstants.success.withValues(alpha: 0.3), width: 2),
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
                    color: AppThemeConstants.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppThemeConstants.success,
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
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppThemeConstants.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (teacherRating == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_outline, size: 15, color: AppThemeConstants.warning),
                        SizedBox(width: 4),
                        Text(
                          'بانتظار تقييمك',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppThemeConstants.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Previous assignment evaluation
            if (previousHifzCompleted != null ||
                previousMurajaCompleted != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in,
                      size: 18, color: AppThemeConstants.textPrimary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ArabicLabels.assignmentPerformanceInPreviousTask,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppThemeConstants.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (previousHifzCompleted != null)
                _buildPerformanceBadge(
                  ArabicLabels.previousHifz,
                  previousHifzCompleted,
                  previousHifzRating,
                  Colors.green,
                ),
              if (previousMurajaCompleted != null) ...[
                const SizedBox(height: 8),
                _buildPerformanceBadge(
                  ArabicLabels.previousMuraja,
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
                    color: AppThemeConstants.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppThemeConstants.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note, size: 16, color: AppThemeConstants.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              ArabicLabels.performanceNotesOnYourWork,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppThemeConstants.warning,
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

            // Next assignment
            if (hifz.isNotEmpty || muraja.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.assignment, size: 18, color: AppThemeConstants.textSecondary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ArabicLabels.newAssignmentForNextSession,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppThemeConstants.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (hifz.isNotEmpty)
                _CompletedAssignmentItem(
                  icon: Icons.book,
                  label: ArabicLabels.hifz,
                  content: hifz,
                  color: AppThemeConstants.success,
                ),
              if (hifz.isNotEmpty && muraja.isNotEmpty)
                const SizedBox(height: 12),
              if (muraja.isNotEmpty)
                _CompletedAssignmentItem(
                  icon: Icons.refresh,
                  label: ArabicLabels.muraja,
                  content: muraja,
                  color: AppThemeConstants.primaryVariant,
                ),
            ],

            // Message from mohaffez
            if (sessionNotes != null && sessionNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppThemeConstants.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppThemeConstants.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.message, size: 16, color: AppThemeConstants.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            ArabicLabels.messageFromMohaffez,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppThemeConstants.primary,
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

            // Mistakes review card
            _MistakeReviewCard(session: session),

            // Rating section
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (teacherRating == 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _navigateToRating,
                  icon: const Icon(Icons.star_outline, color: AppThemeConstants.onPrimary),
                  label: const Text(
                    ArabicLabels.rateSession,
                    style: TextStyle(fontSize: 16, color: AppThemeConstants.onPrimary),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppThemeConstants.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppThemeConstants.success.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: AppThemeConstants.success, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'تم تقييم هذه الجلسة',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppThemeConstants.success,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 16, color: AppThemeConstants.secondary),
                        const SizedBox(width: 4),
                        Text(
                          '$teacherRating/10',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppThemeConstants.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Performance badge
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
            color: completed ? color : AppThemeConstants.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          if (completed) ...[
            Expanded(
              child: Row(
                children: [
                  ...List.generate(
                    rating > 5 ? 5 : rating,
                    (index) =>
                        const Icon(Icons.star, size: 14, color: AppThemeConstants.secondary),
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
            const Expanded(
              child: Text(
              ArabicLabels.assignmentNotCompleted,
              style: TextStyle(
                fontSize: 13,
                color: AppThemeConstants.error,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// ASSIGNMENT ITEM WIDGET (COMPLETED)
// ============================================================================

class _CompletedAssignmentItem extends StatefulWidget {
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
  State<_CompletedAssignmentItem> createState() => _CompletedAssignmentItemState();
}

class _CompletedAssignmentItemState extends State<_CompletedAssignmentItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 16, color: widget.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: _isExpanded ? null : 3,
                  overflow: _isExpanded ? null : TextOverflow.ellipsis,
                ),
                if (!_isExpanded)
                  InkWell(
                    onTap: () => setState(() => _isExpanded = true),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        ArabicLabels.seeMore,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

// ============================================================================
// MISTAKE REVIEW CARD - Shows mistakes from the session for student review
// ============================================================================

class _MistakeReviewCard extends StatelessWidget {
  final Map<String, dynamic> session;
  late final List<QuranMistake> _mistakes;

  _MistakeReviewCard({required this.session}) {
    final mistakesData = session['mistakes'] as List<dynamic>?;
    if (mistakesData == null || mistakesData.isEmpty) {
      _mistakes = [];
    } else {
      _mistakes = mistakesData
          .whereType<Map<String, dynamic>>()
          .map((m) => QuranMistake.fromMap(m))
          .toList();
    }
  }

  void _openMushaf(BuildContext context) {
    if (_mistakes.isEmpty) return;
    
    final startPage = _mistakes.first.pageNumber;
    
    context.push(
      '/mushaf/$startPage',
      extra: <String, dynamic>{'mistakes': _mistakes},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mistakes.isEmpty) return const SizedBox.shrink();

    // Group mistakes by type for the chips
    final mistakesByType = groupMistakesByType(_mistakes);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeConstants.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeConstants.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.menu_book, color: AppThemeConstants.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ArabicLabels.sessionMistakes} (${_mistakes.length})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Mistake type chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mistakesByType.entries.map((entry) {
              return Chip(
                avatar: Icon(
                  getMistakeIcon(entry.key),
                  size: 14,
                  color: Colors.white,
                ),
                label: Text(
                  '${entry.key.arabicLabel} (${entry.value})',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: getMistakeColor(entry.key),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Review button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openMushaf(context),
              icon: const Icon(Icons.auto_stories),
              label: const Text(ArabicLabels.reviewMistakesInMushaf),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.primary,
                foregroundColor: AppThemeConstants.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



