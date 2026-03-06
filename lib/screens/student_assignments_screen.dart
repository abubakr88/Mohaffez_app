// lib/screens/student_assignments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/constants/app_theme.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/widgets/interactive_quran_page.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/user_provider.dart';
import '../utils/arabic_labels.dart';
import '../models/quran_mistake_model.dart';
import '../utils/quran_mistake_utils.dart';

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
                                    color: Colors.white.withValues(alpha: 0.2),
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
                                    ArabicLabels.myAssignments,
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
              ),

              SliverFillRemaining(
                child: sessionsAsync.when(
                  data: (sessions) {
                    final completedSessions = sessions
                        .where((s) => (s['status'] as String?) == 'completed')
                        .toList();

                    if (completedSessions.isEmpty) {
                      return const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: ArabicLabels.noCompletedAssignments,
                        message: ArabicLabels.completeAssignmentsToAppear,
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

class _CompletedAssignmentCard extends ConsumerWidget {
  final Map<String, dynamic> session;
  final String studentId;

  const _CompletedAssignmentCard({
    required this.session,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mohaffezName =
        session['mohaffezName'] as String? ?? ArabicLabels.mohaffez;
    final hifz = session['hifzAssignment'] as String? ?? '';
    final muraja = session['murajaAssignment'] as String? ?? '';
    final sessionDate = session['sessionDate'] as DateTime?;

    // Evaluation values
    final previousHifzCompleted = session['previousHifzCompleted'] as bool?;
    final previousHifzRating = session['previousHifzRating'] as int? ?? 0;
    final previousMurajaCompleted = session['previousMurajaCompleted'] as bool?;
    final previousMurajaRating = session['previousMurajaRating'] as int? ?? 0;
    final performanceNotes = session['performanceNotes'] as String?;
    final sessionRating = session['sessionRating'] as int? ?? 0;
    final sessionNotes = session['sessionNotes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.withValues(alpha: 0.3), width: 2),
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
                    color: Colors.green.withValues(alpha: 0.1),
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
                // Session rating
                if (sessionRating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
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
                    color: AppThemeConstants.primaryAmber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppThemeConstants.primaryAmber.withValues(alpha: 0.4)),
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
                              ArabicLabels.performanceNotesOnYourWork,
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

            // Next assignment
            if (hifz.isNotEmpty || muraja.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.assignment, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ArabicLabels.newAssignmentForNextSession,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
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
                  color: Colors.green,
                ),
              if (hifz.isNotEmpty && muraja.isNotEmpty)
                const SizedBox(height: 12),
              if (muraja.isNotEmpty)
                _CompletedAssignmentItem(
                  icon: Icons.refresh,
                  label: ArabicLabels.muraja,
                  content: muraja,
                  color: Colors.blue,
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
                            ArabicLabels.messageFromMohaffez,
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

            // Mistakes review card
            _MistakeReviewCard(session: session),
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
            color: completed ? color : Colors.red,
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
            Expanded(
              child: Text(
              ArabicLabels.assignmentNotCompleted,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade700,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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

  const _MistakeReviewCard({required this.session});

  List<QuranMistake> get _mistakes {
    final mistakesData = session['mistakes'] as List<dynamic>?;
    if (mistakesData == null || mistakesData.isEmpty) return [];
    return mistakesData
        .whereType<Map<String, dynamic>>()
        .map((m) => QuranMistake.fromMap(m))
        .toList();
  }

  void _openMushaf(BuildContext context) {
    if (_mistakes.isEmpty) return;
    
    final startPage = _mistakes.first.pageNumber;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(ArabicLabels.reviewMistakes),
              backgroundColor: AppThemeConstants.primaryAmber,
            ),
            body: InteractiveQuranPage(
              pageNumber: startPage,
              existingMistakes: _mistakes,
              onMistakeAdded: (_) {}, // read-only no-op
              isEditable: false,
            ),
          ),
        ),
      ),
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
        color: AppThemeConstants.primaryAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeConstants.primaryAmber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.menu_book, color: AppThemeConstants.primaryAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ArabicLabels.sessionMistakes} (${_mistakes.length})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.primaryAmber,
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
                backgroundColor: AppThemeConstants.primaryAmber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



