// screens/completed_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';

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

enum _SortOrder { newestFirst, oldestFirst }

class _CompletedSessionsScreenState
    extends ConsumerState<CompletedSessionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _SortOrder _sortOrder = _SortOrder.newestFirst;
  int _minRating = 0; // 0 = show all

  @override
  void dispose() {
    _searchController.dispose();
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
                automaticallyImplyLeading: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: AppThemeConstants.deepTeal,
                surfaceTintColor: AppThemeConstants.transparent,
                title: const Text(ArabicLabels.completedSessions),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppThemeConstants.tealGradient,
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
                                    color: AppThemeConstants.surface.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.done_all,
                                    size: 28,
                                    color: AppThemeConstants.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        ArabicLabels.completedSessions,
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: AppThemeConstants.onPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ArabicLabels.sessionHistory,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppThemeConstants.onPrimary.withValues(alpha: 0.7),
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
              ),

              // Search + Sort/Filter Bar
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search field
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase().trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'ابحث باسم الطالب...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppThemeConstants.grey100,
                        ),
                      ),
                    ),

                    // Sort + Rating filter row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          // Sort dropdown
                          Expanded(
                            child: DropdownButtonFormField<_SortOrder>(
                              initialValue: _sortOrder,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: AppThemeConstants.grey100,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: _SortOrder.newestFirst,
                                  child: Text('الأحدث أولاً',
                                      style: TextStyle(fontSize: 13)),
                                ),
                                DropdownMenuItem(
                                  value: _SortOrder.oldestFirst,
                                  child: Text('الأقدم أولاً',
                                      style: TextStyle(fontSize: 13)),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _sortOrder = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Min rating filter
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _minRating,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: AppThemeConstants.grey100,
                              ),
                              items: [
                                const DropdownMenuItem(
                                    value: 0,
                                    child: Text('كل التقييمات',
                                        style: TextStyle(fontSize: 13))),
                                ...List.generate(
                                  10,
                                  (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text('★ ${i + 1}+',
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _minRating = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Active filter chips + count badge
                    sessionsAsync.when(
                      data: (allSessions) {
                        // Compute filtered count to show in badge
                        var filtered = allSessions.where((s) {
                          if (_searchQuery.isNotEmpty) {
                            final name = (s['studentName'] as String? ?? '')
                                .toLowerCase();
                            if (!name.contains(_searchQuery)) return false;
                          }
                          if (_minRating > 0) {
                            final rating = s['sessionRating'] as int? ?? 0;
                            if (rating < _minRating) return false;
                          }
                          return true;
                        }).toList();

                        final hasActiveFilters =
                            _searchQuery.isNotEmpty || _minRating > 0;

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppThemeConstants.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppThemeConstants.primary
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'الجلسات: ${filtered.length}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppThemeConstants.primary,
                                  ),
                                ),
                              ),
                              if (hasActiveFilters) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _minRating = 0;
                                      _sortOrder = _SortOrder.newestFirst;
                                    });
                                  },
                                  icon: const Icon(Icons.filter_alt_off,
                                      size: 16),
                                  label: const Text('إزالة الفلاتر',
                                      style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    foregroundColor: AppThemeConstants.grey600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              // Sessions List
              sessionsAsync.when(
                data: (allSessions) {
                  if (allSessions.isEmpty) {
                    return const SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.history,
                        title: ArabicLabels.noCompletedSessions,
                        message: ArabicLabels.noSessionsMessage,
                        animated: true,
                      ),
                    );
                  }

                  // 1. Search filter
                  var filteredSessions = _searchQuery.isEmpty
                      ? allSessions
                      : allSessions.where((session) {
                          final studentName =
                              (session['studentName'] as String? ?? '')
                                  .toLowerCase();
                          return studentName.contains(_searchQuery);
                        }).toList();

                  // 2. Rating filter
                  if (_minRating > 0) {
                    filteredSessions = filteredSessions.where((session) {
                      final rating = session['sessionRating'] as int? ?? 0;
                      return rating >= _minRating;
                    }).toList();
                  }

                  // 3. Sort
                  filteredSessions = List.of(filteredSessions)
                    ..sort((a, b) {
                      final aDate = a['completedAt'] as DateTime?;
                      final bDate = b['completedAt'] as DateTime?;
                      if (aDate == null && bDate == null) return 0;
                      if (aDate == null) return 1;
                      if (bDate == null) return -1;
                      return _sortOrder == _SortOrder.newestFirst
                          ? bDate.compareTo(aDate)
                          : aDate.compareTo(bDate);
                    });

                  if (filteredSessions.isEmpty) {
                    return SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.search_off,
                        title: ArabicLabels.noSearchResults,
                        message: 'لم يتم العثور على جلسات تطابق بحثك',
                        animated: true,
                        action: TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _minRating = 0;
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('مسح الفلاتر'),
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
        side: BorderSide(color: AppThemeConstants.primary.withValues(alpha: 0.3), width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        trailing: const Icon(Icons.expand_more),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppThemeConstants.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.check_circle,
            color: AppThemeConstants.primary,
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
                const Icon(Icons.calendar_today,
                    size: 12, color: AppThemeConstants.grey600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    completedAt != null
                        ? '${ArabicLabels.completed} ${DateFormat('d MMMM y', 'ar').format(completedAt)}'
                        : ArabicLabels.notSpecified,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppThemeConstants.grey600),
                  ),
                ),
              ],
            ),
            if (sessionRating > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.accentAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppThemeConstants.accentAmber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppThemeConstants.accentAmber),
                        const SizedBox(width: 4),
                        Text(
                          '$sessionRating/10',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppThemeConstants.accentAmber,
                          ),
                        ),
                      ],
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
              color: AppThemeConstants.accentBlue,
            ),
            const SizedBox(height: 12),
            if (previousHifzCompleted != null)
              _buildAssignmentEvaluation(
                label: ArabicLabels.hifz,
                completed: previousHifzCompleted,
                rating: previousHifzRating,
                color: AppThemeConstants.success,
              ),
            if (previousMurajaCompleted != null) ...[
              const SizedBox(height: 8),
              _buildAssignmentEvaluation(
                label: ArabicLabels.muraja,
                completed: previousMurajaCompleted,
                rating: previousMurajaRating,
                color: AppThemeConstants.accentBlue,
              ),
            ],
            if (performanceNotes != null && performanceNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppThemeConstants.warningLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppThemeConstants.accentOrange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.note, size: 16, color: AppThemeConstants.warning),
                        SizedBox(width: 6),
                        Text(
                          '${ArabicLabels.performanceNotes}:',
                          style: TextStyle(
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
              color: AppThemeConstants.primary,
            ),
            const SizedBox(height: 12),
            if (hifzAssignment != null && hifzAssignment.isNotEmpty)
              _buildAssignmentDisplay(
                label: ArabicLabels.hifz,
                content: hifzAssignment,
                color: AppThemeConstants.success,
                isHifz: true,
              ),
            if (murajaAssignment != null && murajaAssignment.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildAssignmentDisplay(
                label: ArabicLabels.muraja,
                content: murajaAssignment,
                color: AppThemeConstants.accentBlue,
              ),
            ],
            const SizedBox(height: 16),
          ],

          // General notes
          if (sessionNotes != null && sessionNotes.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.notes,
              title: ArabicLabels.notes,
              color: AppThemeConstants.primary,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeConstants.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppThemeConstants.primary.withValues(alpha: 0.3)),
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
            color: AppThemeConstants.grey500,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.category,
            ArabicLabels.type,
            ArabicLabels.getSessionTypeLabel(sessionType),
          ),
          if (location.isNotEmpty)
            _buildInfoRow(Icons.location_on, ArabicLabels.location, location),
          if (sessionDate != null)
            _buildInfoRow(
              Icons.event,
              ArabicLabels.sessionDate,
              DateFormat('d MMMM y', 'ar').format(sessionDate),
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
            color: completed ? color : AppThemeConstants.error,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppThemeConstants.accentAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppThemeConstants.accentAmber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 14, color: AppThemeConstants.accentAmber),
                  const SizedBox(width: 4),
                  Text(
                    '$rating/10',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.accentAmber,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Text(
              ArabicLabels.assignmentNotCompleted,
              style: TextStyle(
                fontSize: 13,
                color: AppThemeConstants.error,
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
    bool isHifz = false,
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
                isHifz ? Icons.menu_book : Icons.history_edu,
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
          Icon(icon, size: 16, color: AppThemeConstants.grey600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppThemeConstants.grey700,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : ArabicLabels.notSpecified,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
