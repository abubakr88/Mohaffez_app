// screens/completed_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/session_provider_paginated.dart';
import '../utils/arabic_labels.dart';

class CompletedSessionsScreen extends ConsumerStatefulWidget {
  final String mohaffezId;

  const CompletedSessionsScreen({
    super.key,
    required this.mohaffezId,
  });

  @override
  ConsumerState<CompletedSessionsScreen> createState() =>
      _CompletedSessionsScreenState();
}

class _CompletedSessionsScreenState
    extends ConsumerState<CompletedSessionsScreen> {
  final searchController = TextEditingController();
  String searchQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync =
        ref.watch(completedSessionsProvider(widget.mohaffezId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(completedSessionsProvider(widget.mohaffezId));
            await ref
                .read(completedSessionsProvider(widget.mohaffezId).future)
                .catchError((_) => <Map<String, dynamic>>[]);
          },
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 130,
                floating: true,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple, Color(0xFFAB47BC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 16, 14),
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
                                    Icons.done_all,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ArabicLabels.completedSessions,
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ArabicLabels.sessionHistory,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Total Count
                                sessionsAsync.when(
                                  data: (sessions) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      sessions.length.toString(),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ),
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
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

              // Search Bar
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase().trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: ArabicLabels.searchStudents,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
              ),

              // Sessions List
              sessionsAsync.when(
                data: (allSessions) {
                  if (allSessions.isEmpty) {
                    return SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.history,
                        title: ArabicLabels.noCompletedSessions,
                        message: ArabicLabels.noSessionsMessage,
                        animated: true,
                      ),
                    );
                  }

                  // Apply search filter
                  final filteredSessions = searchQuery.isEmpty
                      ? allSessions
                      : allSessions.where((session) {
                          final studentName =
                              (session['studentName'] as String? ?? '')
                                  .toLowerCase();
                          return studentName.contains(searchQuery);
                        }).toList();

                  if (filteredSessions.isEmpty) {
                    return SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.search_off,
                        title: ArabicLabels.noSearchResults,
                        message: ArabicLabels.noSessionsMessage,
                        animated: true,
                        action: TextButton.icon(
                          onPressed: () {
                            searchController.clear();
                            setState(() {
                              searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: Text(ArabicLabels.clearSearch),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final session = filteredSessions[index];
                          return CompletedSessionCard(session: session);
                        },
                        childCount: filteredSessions.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: ErrorDisplay.dataLoad(
                    onRetry: () {
                      ref.invalidate(
                          completedSessionsProvider(widget.mohaffezId));
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class CompletedSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const CompletedSessionCard({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final studentName =
        session['studentName'] as String? ?? ArabicLabels.notSpecified;
    final completedAt = session['completedAt'] as DateTime?;
    final sessionDate = session['sessionDate'] as DateTime?;
    final location = session['location'] as String? ?? '';
    final sessionType = session['sessionType'] as String? ?? '';

    // Assignments
    final hifzAssignment = session['hifzAssignment'] as String?;
    final murajaAssignment = session['murajaAssignment'] as String?;

    // New evaluation fields
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
        side: BorderSide(color: Colors.purple.withValues(alpha: 0.3), width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.check_circle,
            color: Colors.purple,
            size: 24,
          ),
        ),
        title: Text(
          studentName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  completedAt != null
                      ? '${ArabicLabels.completed} ${DateFormat('dd/MM/yyyy', 'ar').format(completedAt)}'
                      : ArabicLabels.notSpecified,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (sessionRating > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  ...List.generate(
                    10,
                    (index) => Icon(
                      index < sessionRating ? Icons.star : Icons.star_border,
                      size: 14,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$sessionRating/10',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Previous assignment evaluation
          if (previousHifzCompleted != null ||
              previousMurajaCompleted != null) ...[
            _buildSectionHeader(
              icon: Icons.assignment_turned_in,
              title: ArabicLabels.previousAssignments,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            if (previousHifzCompleted != null)
              _buildAssignmentEvaluation(
                label: ArabicLabels.hifz,
                completed: previousHifzCompleted,
                rating: previousHifzRating,
                color: Colors.green,
              ),
            if (previousMurajaCompleted != null) ...[
              const SizedBox(height: 8),
              _buildAssignmentEvaluation(
                label: ArabicLabels.muraja,
                completed: previousMurajaCompleted,
                rating: previousMurajaRating,
                color: Colors.blue,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.note, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          '${ArabicLabels.performanceNotes}:',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      performanceNotes,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // New assignments given
          if (hifzAssignment != null || murajaAssignment != null) ...[
            _buildSectionHeader(
              icon: Icons.assignment,
              title: ArabicLabels.nextAssignments,
              color: AppTheme.primaryAmber,
            ),
            const SizedBox(height: 12),
            if (hifzAssignment != null && hifzAssignment.isNotEmpty)
              _buildAssignmentDisplay(
                label: ArabicLabels.hifz,
                content: hifzAssignment,
                color: Colors.green,
              ),
            if (murajaAssignment != null && murajaAssignment.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildAssignmentDisplay(
                label: ArabicLabels.muraja,
                content: murajaAssignment,
                color: Colors.blue,
              ),
            ],
            const SizedBox(height: 16),
          ],

          // General notes
          if (sessionNotes != null && sessionNotes.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.notes,
              title: ArabicLabels.notes,
              color: Colors.purple,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Text(
                sessionNotes,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Session information
          _buildSectionHeader(
            icon: Icons.info_outline,
            title: ArabicLabels.sessionDetails,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.category,
            ArabicLabels.type,
            ArabicLabels.getSessionTypeLabel(sessionType),
          ),
          _buildInfoRow(Icons.location_on, ArabicLabels.location, location),
          if (sessionDate != null)
            _buildInfoRow(
              Icons.event,
              ArabicLabels.sessionDate,
              DateFormat('dd/MM/yyyy', 'ar').format(sessionDate),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentEvaluation({
    required String label,
    required bool completed,
    required int rating,
    required Color color,
  }) {
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
            color: completed ? color : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          if (completed) ...[
            ...List.generate(
              10,
              (index) => Icon(
                index < rating ? Icons.star : Icons.star_border,
                size: 14,
                color: Colors.amber,
              ),
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
          ] else
            Text(
              ArabicLabels.assignmentNotCompleted,
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

  Widget _buildAssignmentDisplay({
    required String label,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                label == ArabicLabels.hifz
                    ? Icons.menu_book
                    : Icons.history_edu,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : ArabicLabels.notSpecified,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
