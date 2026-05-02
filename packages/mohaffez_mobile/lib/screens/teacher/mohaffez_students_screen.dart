// lib/screens/teacher/mohaffez_students_screen.dart

import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sort options
// ─────────────────────────────────────────────────────────────────────────────
enum _SortBy { lastSession, sessionCount, rating, name }

extension _SortByX on _SortBy {
  String get label => switch (this) {
        _SortBy.lastSession => 'آخر جلسة',
        _SortBy.sessionCount => 'عدد الجلسات',
        _SortBy.rating => 'التقييم',
        _SortBy.name => 'الاسم',
      };
  IconData get icon => switch (this) {
        _SortBy.lastSession => Icons.calendar_today,
        _SortBy.sessionCount => Icons.school,
        _SortBy.rating => Icons.star,
        _SortBy.name => Icons.sort_by_alpha,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Root widget — resolves authenticated user only
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
// Inner body — owns all filter/sort/search state
// ─────────────────────────────────────────────────────────────────────────────
class _StudentsBody extends ConsumerStatefulWidget {
  final String mohaffezId;

  const _StudentsBody({required this.mohaffezId});

  @override
  ConsumerState<_StudentsBody> createState() => _StudentsBodyState();
}

class _StudentsBodyState extends ConsumerState<_StudentsBody> {
  final _searchCtrl = TextEditingController();
  _SortBy _sortBy = _SortBy.lastSession;
  bool _sortAsc = false;
  bool _filterHifz = false;
  bool _filterMuraja = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount =>
      (_filterHifz ? 1 : 0) + (_filterMuraja ? 1 : 0);

  List<MohaffezStudentSummary> _applyFilters(
      List<MohaffezStudentSummary> all) {
    var list = all.where((s) {
      if (_searchQuery.isNotEmpty &&
          !s.studentName.contains(_searchQuery)) {
        return false;
      }
      if (_filterHifz && s.hifzAssignment.isEmpty) return false;
      if (_filterMuraja && s.murajaAssignment.isEmpty) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      final int cmp;
      switch (_sortBy) {
        case _SortBy.lastSession:
          cmp = (b.lastSessionDate ?? DateTime(0))
              .compareTo(a.lastSessionDate ?? DateTime(0));
        case _SortBy.sessionCount:
          cmp = b.sessionCount.compareTo(a.sessionCount);
        case _SortBy.rating:
          cmp = b.sessionRating.compareTo(a.sessionRating);
        case _SortBy.name:
          cmp = a.studentName.compareTo(b.studentName);
      }
      return _sortAsc ? -cmp : cmp;
    });

    return list;
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppThemeConstants.grey300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ترتيب حسب',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                RadioGroup<_SortBy>(
                  groupValue: _sortBy,
                  onChanged: (val) {
                    if (val == null) return;
                    setSheet(() {});
                    setState(() => _sortBy = val);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _SortBy.values
                        .map((opt) => RadioListTile<_SortBy>(
                              value: opt,
                              title: Row(
                                children: [
                                  Icon(_SortByX(opt).icon,
                                      size: 16,
                                      color: _sortBy == opt
                                          ? AppThemeConstants.primary
                                          : AppThemeConstants.grey500),
                                  const SizedBox(width: 8),
                                  Text(_SortByX(opt).label),
                                ],
                              ),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ))
                        .toList(),
                  ),
                ),
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                    color: AppThemeConstants.primary,
                    size: 20,
                  ),
                  title: Text(_sortAsc ? 'تصاعدي' : 'تنازلي'),
                  trailing: Switch.adaptive(
                    value: _sortAsc,
                    activeThumbColor: AppThemeConstants.primary,
                    onChanged: (val) {
                      setSheet(() {});
                      setState(() => _sortAsc = val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync =
        ref.watch(mohaffezStudentsProvider(widget.mohaffezId));
    final totalCount = studentsAsync.valueOrNull?.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mohaffezStudentsProvider(widget.mohaffezId));
            await ref
                .read(mohaffezStudentsProvider(widget.mohaffezId).future)
                .catchError((_) => <MohaffezStudentSummary>[]);
          },
          child: CustomScrollView(
            slivers: [
              // ── AppBar with embedded search ──────────────────────────────
              SliverAppBar(
                expandedHeight: 140,
                floating: true,
                pinned: true,
                automaticallyImplyLeading: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: AppThemeConstants.deepTeal,
                surfaceTintColor: AppThemeConstants.transparent,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(52),
                  child: Container(
                    color: AppThemeConstants.deepTeal,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppThemeConstants.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppThemeConstants.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v),
                        style: const TextStyle(
                            color: AppThemeConstants.white, fontSize: 14),
                        cursorColor: AppThemeConstants.white,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'ابحث باسم الطالب...',
                          hintStyle: TextStyle(
                            color: AppThemeConstants.white.withValues(alpha: 0.65),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(Icons.search,
                              color: AppThemeConstants.white70, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.clear,
                                      color: AppThemeConstants.white70, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ),
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 62),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppThemeConstants.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.groups,
                                  size: 24,
                                  color: AppThemeConstants.onPrimary),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'طلابي',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppThemeConstants.onPrimary,
                                    height: 1.2,
                                  ),
                                ),
                                if (totalCount != null)
                                  Text(
                                    '$totalCount طالب',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppThemeConstants.white
                                          .withValues(alpha: 0.75),
                                      height: 1.2,
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

              // ── Filter / Sort bar (pinned, scrolls with header) ──────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _FilterBarDelegate(
                  sortBy: _sortBy,
                  sortAsc: _sortAsc,
                  filterHifz: _filterHifz,
                  filterMuraja: _filterMuraja,
                  activeFilterCount: _activeFilterCount,
                  onSortTap: _showSortSheet,
                  onHifzToggle: (v) => setState(() => _filterHifz = v),
                  onMurajaToggle: (v) =>
                      setState(() => _filterMuraja = v),
                  onClearAll: () => setState(() {
                    _filterHifz = false;
                    _filterMuraja = false;
                  }),
                ),
              ),

              // ── Student list ─────────────────────────────────────────────
              studentsAsync.when(
                skipLoadingOnRefresh: true,
                data: (students) {
                  if (students.isEmpty) {
                    return const SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.people_outline,
                        title: 'لا يوجد طلاب بعد',
                        message:
                            'ستظهر هنا قائمة طلابك بعد إجراء أول جلسة',
                        animated: true,
                      ),
                    );
                  }

                  final filtered = _applyFilters(students);

                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.search_off,
                        title: 'لا توجد نتائج',
                        message: _searchQuery.isNotEmpty
                            ? 'لا يوجد طالب باسم "$_searchQuery"'
                            : 'جرّب تغيير معايير الفلتر',
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          if (index == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ResultsHeader(
                                  total: students.length,
                                  filtered: filtered.length,
                                ),
                                const SizedBox(height: 8),
                                StudentCard(
                                  student: filtered[0],
                                  onTap: () => context.push(
                                    '/student/${filtered[0].studentId}',
                                    extra: filtered[0],
                                  ),
                                ),
                              ],
                            );
                          }
                          final student = filtered[index];
                          return StudentCard(
                            student: student,
                            onTap: () => context.push(
                              '/student/${student.studentId}',
                              extra: student,
                            ),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: _SkeletonList(),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: ErrorDisplay.dataLoad(
                    onRetry: () => ref.invalidate(
                        mohaffezStudentsProvider(widget.mohaffezId)),
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
// Pinned filter + sort bar
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final _SortBy sortBy;
  final bool sortAsc;
  final bool filterHifz;
  final bool filterMuraja;
  final int activeFilterCount;
  final VoidCallback onSortTap;
  final ValueChanged<bool> onHifzToggle;
  final ValueChanged<bool> onMurajaToggle;
  final VoidCallback onClearAll;

  _FilterBarDelegate({
    required this.sortBy,
    required this.sortAsc,
    required this.filterHifz,
    required this.filterMuraja,
    required this.activeFilterCount,
    required this.onSortTap,
    required this.onHifzToggle,
    required this.onMurajaToggle,
    required this.onClearAll,
  });

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  bool shouldRebuild(_FilterBarDelegate old) =>
      sortBy != old.sortBy ||
      sortAsc != old.sortAsc ||
      filterHifz != old.filterHifz ||
      filterMuraja != old.filterMuraja ||
      activeFilterCount != old.activeFilterCount;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(
          bottom: BorderSide(color: AppThemeConstants.grey200),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Sort button
            _SortButton(
              label: _SortByX(sortBy).label,
              ascending: sortAsc,
              onTap: onSortTap,
            ),
            const SizedBox(width: 8),
            // Hifz filter chip
            FilterChip(
              label: const Text('لديهم حفظ'),
              selected: filterHifz,
              onSelected: onHifzToggle,
              avatar: Icon(Icons.menu_book,
                  size: 14,
                  color: filterHifz ? AppThemeConstants.success : AppThemeConstants.grey500),
              selectedColor: AppThemeConstants.success.withValues(alpha: 0.12),
              checkmarkColor: AppThemeConstants.success,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: filterHifz ? FontWeight.w700 : FontWeight.normal,
                color: filterHifz ? AppThemeConstants.success : null,
              ),
              side: filterHifz
                  ? const BorderSide(color: AppThemeConstants.accentGreenAlt)
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            const SizedBox(width: 8),
            // Muraja filter chip
            FilterChip(
              label: const Text('لديهم مراجعة'),
              selected: filterMuraja,
              onSelected: onMurajaToggle,
              avatar: Icon(Icons.refresh,
                  size: 14,
                  color: filterMuraja ? AppThemeConstants.accentBlue : AppThemeConstants.grey500),
              selectedColor: AppThemeConstants.accentBlue.withValues(alpha: 0.12),
              checkmarkColor: AppThemeConstants.accentBlue,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight:
                    filterMuraja ? FontWeight.w700 : FontWeight.normal,
                color: filterMuraja ? AppThemeConstants.accentBlueDark : null,
              ),
              side: filterMuraja
                  ? const BorderSide(color: AppThemeConstants.accentBlue)
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // Clear all — only when filters active
            if (activeFilterCount > 0) ...[
              const SizedBox(width: 8),
              ActionChip(
                label: Text('مسح ($activeFilterCount)'),
                onPressed: onClearAll,
                avatar: const Icon(Icons.close, size: 14, color: AppThemeConstants.error),
                backgroundColor: AppThemeConstants.error.withValues(alpha: 0.08),
                side: const BorderSide(color: AppThemeConstants.accentRed),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: AppThemeConstants.error,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final bool ascending;
  final VoidCallback onTap;

  const _SortButton({
    required this.label,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppThemeConstants.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppThemeConstants.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 13,
              color: AppThemeConstants.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppThemeConstants.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more,
                size: 14, color: AppThemeConstants.primary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results header — shows count / filtered count
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsHeader extends StatelessWidget {
  final int total;
  final int filtered;

  const _ResultsHeader({required this.total, required this.filtered});

  @override
  Widget build(BuildContext context) {
    final isFiltered = filtered != total;
    return Row(
      children: [
        Text(
          isFiltered ? '$filtered من $total طالب' : '$total طالب',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isFiltered
                ? AppThemeConstants.primary
                : AppThemeConstants.textSecondary,
          ),
        ),
        if (isFiltered) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppThemeConstants.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'مفلتر',
              style: TextStyle(
                fontSize: 11,
                color: AppThemeConstants.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StudentCard — pure StatelessWidget; no N+1 queries
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
                                size: 12, color: AppThemeConstants.grey500),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                  fontSize: 12, color: AppThemeConstants.grey500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _StatChip(
                    icon: Icons.school,
                    label: '${student.sessionCount}',
                    color: AppThemeConstants.primary,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppThemeConstants.grey500),
                ],
              ),

              const Divider(height: 24),

              // ── Assignments ─────────────────────────────────────────────
              if (student.hifzAssignment.isNotEmpty) ...[
                _AssignmentRow(
                  icon: Icons.menu_book,
                  label: 'حفظ',
                  value: student.hifzAssignment,
                  color: AppThemeConstants.success,
                ),
                const SizedBox(height: 6),
              ],
              if (student.murajaAssignment.isNotEmpty)
                _AssignmentRow(
                  icon: Icons.refresh,
                  label: 'مراجعة',
                  value: student.murajaAssignment,
                  color: AppThemeConstants.accentBlue,
                ),

              // ── Rating ──────────────────────────────────────────────────
              if (student.sessionRating > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: AppThemeConstants.accentAmber),
                    const SizedBox(width: 4),
                    Text(
                      '${student.sessionRating} / 10',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppThemeConstants.accentAmber),
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
                  style: TextStyle(fontSize: 12, color: AppThemeConstants.grey500),
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
                            ? AppThemeConstants.success
                            : AppThemeConstants.error,
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
                            ? AppThemeConstants.success
                            : AppThemeConstants.error,
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
                    color: AppThemeConstants.grey100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notes, size: 14, color: AppThemeConstants.grey500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          student.performanceNotes!,
                          style: const TextStyle(
                              fontSize: 12, color: AppThemeConstants.black87),
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
// Skeleton loading — 5 ghost cards while fetching
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
                      radius: 28, backgroundColor: AppThemeConstants.white),
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
                            color: AppThemeConstants.white,
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
                            color: AppThemeConstants.white,
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
                      color: AppThemeConstants.white,
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
                  color: AppThemeConstants.white,
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
                  color: AppThemeConstants.white,
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
      decoration: const BoxDecoration(color: AppThemeConstants.grey200),
      child: child,
    );
  }
}
