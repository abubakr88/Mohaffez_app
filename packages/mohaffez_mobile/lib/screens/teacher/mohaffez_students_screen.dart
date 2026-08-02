// lib/screens/teacher/mohaffez_students_screen.dart

import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';
import 'teacher_active_bundle_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — single source for radii / spacing in this screen
// ─────────────────────────────────────────────────────────────────────────────
class _R {
  static const card = 24.0;
  static const input = 18.0;
  static const pill = 16.0;
  static const badge = 10.0;
}

const _kScreenBg = Color(0xFFF7FAF9);

// ─────────────────────────────────────────────────────────────────────────────
// Segmented filter (single-select)
// ─────────────────────────────────────────────────────────────────────────────
enum _Segment { all, hifz, muraja }

enum _StudentsView { students, activeBundles }

extension _SegmentX on _Segment {
  String get label => switch (this) {
        _Segment.all => 'الكل',
        _Segment.hifz => 'حفظ',
        _Segment.muraja => 'مراجعة',
      };
  IconData get icon => switch (this) {
        _Segment.all => Icons.apps_rounded,
        _Segment.hifz => Icons.menu_book_rounded,
        _Segment.muraja => Icons.history_edu_rounded,
      };
}

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
  _StudentsView _view = _StudentsView.students;
  _SortBy _sortBy = _SortBy.lastSession;
  bool _sortAsc = false;
  bool _filterHifz = false;
  bool _filterMuraja = false;
  String _searchQuery = '';

  void _changeView(_StudentsView view) {
    if (_view == view) return;
    _searchCtrl.clear();
    setState(() {
      _view = view;
      _searchQuery = '';
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  _Segment _segmentFromFilters() {
    if (_filterHifz && !_filterMuraja) return _Segment.hifz;
    if (_filterMuraja && !_filterHifz) return _Segment.muraja;
    return _Segment.all;
  }

  void _applySegment(_Segment s) {
    setState(() {
      _filterHifz = s == _Segment.hifz;
      _filterMuraja = s == _Segment.muraja;
    });
  }

  List<MohaffezStudentSummary> _applyFilters(List<MohaffezStudentSummary> all) {
    var list = all.where((s) {
      if (_searchQuery.isNotEmpty && !s.studentName.contains(_searchQuery)) {
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

  List<TeacherActiveBundleInfo> _filterBundles(
    List<TeacherActiveBundleInfo> bundles,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return bundles;
    return bundles.where((bundle) {
      return bundle.learnerName.toLowerCase().contains(query) ||
          (bundle.guardianDisplayName?.toLowerCase().contains(query) ??
              false) ||
          bundle.planTitle.toLowerCase().contains(query);
    }).toList();
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

  Future<void> _refresh() async {
    if (_view == _StudentsView.activeBundles) {
      ref.invalidate(teacherActiveBundlesProvider(widget.mohaffezId));
      await ref
          .read(teacherActiveBundlesProvider(widget.mohaffezId).future)
          .catchError((_) => <TeacherActiveBundleInfo>[]);
      return;
    }
    ref.invalidate(mohaffezStudentsProvider(widget.mohaffezId));
    await ref
        .read(mohaffezStudentsProvider(widget.mohaffezId).future)
        .catchError((_) => <MohaffezStudentSummary>[]);
  }

  List<Widget> _studentSlivers(
    AsyncValue<List<MohaffezStudentSummary>> studentsAsync,
  ) {
    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: _SearchFilterDelegate(
          searchCtrl: _searchCtrl,
          searchQuery: _searchQuery,
          segment: _segmentFromFilters(),
          sortLabel: _SortByX(_sortBy).label,
          sortAsc: _sortAsc,
          onSearchChanged: (v) => setState(() => _searchQuery = v),
          onSearchClear: () {
            _searchCtrl.clear();
            setState(() => _searchQuery = '');
          },
          onSegmentChanged: _applySegment,
          onSortTap: _showSortSheet,
        ),
      ),
      studentsAsync.when(
        skipLoadingOnRefresh: true,
        data: (students) {
          if (students.isEmpty) {
            return SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: const EmptyState(
                  icon: Icons.people_outline,
                  title: 'لا يوجد طلاب بعد',
                  message: 'ستظهر هنا قائمة طلابك بعد إجراء أول جلسة',
                  animated: true,
                ),
              ),
            );
          }

          final filtered = _applyFilters(students);
          if (filtered.isEmpty) {
            return SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'لا توجد نتائج',
                  message: _searchQuery.isNotEmpty
                      ? 'لا يوجد طالب باسم "$_searchQuery"'
                      : 'جرّب تغيير معايير الفلتر',
                ),
              ),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, index) {
                  final student = filtered[index];
                  final card = StudentCard(
                    student: student,
                    onTap: () => context.push(
                      '/student/${student.studentId}',
                      extra: student,
                    ),
                  );
                  if (index != 0) return card;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ResultsHeader(
                        total: students.length,
                        filtered: filtered.length,
                      ),
                      const SizedBox(height: 8),
                      card,
                    ],
                  );
                },
                childCount: filtered.length,
              ),
            ),
          );
        },
        loading: () => const SliverToBoxAdapter(child: _SkeletonList()),
        error: (e, _) => SliverToBoxAdapter(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 300),
            child: ErrorDisplay.dataLoad(
              onRetry: () => ref.invalidate(
                mohaffezStudentsProvider(widget.mohaffezId),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _bundleSlivers(
    AsyncValue<List<TeacherActiveBundleInfo>> bundlesAsync,
  ) {
    return [
      SliverToBoxAdapter(
        child: _BundleSearchBar(
          controller: _searchCtrl,
          onChanged: (value) => setState(() => _searchQuery = value),
          onClear: () {
            _searchCtrl.clear();
            setState(() => _searchQuery = '');
          },
        ),
      ),
      bundlesAsync.when(
        skipLoadingOnRefresh: true,
        data: (bundles) {
          final filtered = _filterBundles(bundles);
          if (bundles.isEmpty) {
            return SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: const EmptyState(
                  icon: Icons.workspace_premium_outlined,
                  title: 'لا توجد باقات نشطة',
                  message: 'ستظهر هنا باقات طلابك بعد إتمام الدفع',
                  animated: true,
                ),
              ),
            );
          }
          if (filtered.isEmpty) {
            return SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'لا توجد نتائج',
                  message: 'لا توجد باقة مطابقة لـ "$_searchQuery"',
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, index) {
                  final card = TeacherActiveBundleCard(bundle: filtered[index]);
                  if (index != 0) return card;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${filtered.length} باقة نشطة',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppThemeConstants.textSecondary,
                          ),
                        ),
                      ),
                      card,
                    ],
                  );
                },
                childCount: filtered.length,
              ),
            ),
          );
        },
        loading: () => const SliverToBoxAdapter(child: _SkeletonList()),
        error: (e, _) => SliverToBoxAdapter(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 300),
            child: ErrorDisplay.dataLoad(
              onRetry: () => ref.invalidate(
                teacherActiveBundlesProvider(widget.mohaffezId),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync =
        ref.watch(mohaffezStudentsProvider(widget.mohaffezId));
    final bundlesAsync = _view == _StudentsView.activeBundles
        ? ref.watch(teacherActiveBundlesProvider(widget.mohaffezId))
        : null;
    final totalCount = _view == _StudentsView.students
        ? studentsAsync.valueOrNull?.length
        : bundlesAsync?.valueOrNull?.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kScreenBg,
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                toolbarHeight: 64,
                backgroundColor: AppThemeConstants.primary,
                surfaceTintColor: AppThemeConstants.transparent,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppThemeConstants.tealGradient,
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppThemeConstants.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(_R.pill),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        size: 20,
                        color: AppThemeConstants.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'طلابي',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppThemeConstants.onPrimary,
                      ),
                    ),
                    if (totalCount != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppThemeConstants.secondary,
                          borderRadius: BorderRadius.circular(_R.pill),
                        ),
                        child: Text(
                          '$totalCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppThemeConstants.onSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _StudentsViewSelector(
                  value: _view,
                  onChanged: _changeView,
                ),
              ),
              if (_view == _StudentsView.students)
                ..._studentSlivers(studentsAsync)
              else
                ..._bundleSlivers(bundlesAsync!),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentsViewSelector extends StatelessWidget {
  const _StudentsViewSelector({
    required this.value,
    required this.onChanged,
  });

  final _StudentsView value;
  final ValueChanged<_StudentsView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppThemeConstants.grey100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppThemeConstants.grey300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StudentsViewButton(
                label: 'كل الطلاب',
                icon: Icons.groups_rounded,
                selected: value == _StudentsView.students,
                onTap: () => onChanged(_StudentsView.students),
              ),
            ),
            Expanded(
              child: _StudentsViewButton(
                label: 'الباقات النشطة',
                icon: Icons.workspace_premium_rounded,
                selected: value == _StudentsView.activeBundles,
                onTap: () => onChanged(_StudentsView.activeBundles),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentsViewButton extends StatelessWidget {
  const _StudentsViewButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppThemeConstants.onPrimary
        : AppThemeConstants.textSecondary;
    return Material(
      color: selected ? AppThemeConstants.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BundleSearchBar extends StatelessWidget {
  const _BundleSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'ابحث باسم الطالب أو ولي الأمر أو الباقة',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppThemeConstants.grey300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppThemeConstants.grey300),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned search + segmented filter delegate
// ─────────────────────────────────────────────────────────────────────────────
class _SearchFilterDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final _Segment segment;
  final String sortLabel;
  final bool sortAsc;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final ValueChanged<_Segment> onSegmentChanged;
  final VoidCallback onSortTap;

  _SearchFilterDelegate({
    required this.searchCtrl,
    required this.searchQuery,
    required this.segment,
    required this.sortLabel,
    required this.sortAsc,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onSegmentChanged,
    required this.onSortTap,
  });

  @override
  double get minExtent => 172;
  @override
  double get maxExtent => 172;

  @override
  bool shouldRebuild(_SearchFilterDelegate old) =>
      searchQuery != old.searchQuery ||
      segment != old.segment ||
      sortLabel != old.sortLabel ||
      sortAsc != old.sortAsc;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final elevated = shrinkOffset > 0 || overlapsContent;
    return Container(
      decoration: BoxDecoration(
        color: _kScreenBg,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppThemeConstants.primary.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        children: [
          // Modern search field
          Container(
            height: 58,
            decoration: BoxDecoration(
              color: AppThemeConstants.white,
              borderRadius: BorderRadius.circular(_R.input),
              boxShadow: [
                BoxShadow(
                  color: AppThemeConstants.primary.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14),
              cursorColor: AppThemeConstants.primary,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'ابحث عن طالب...',
                hintStyle: const TextStyle(
                  color: AppThemeConstants.textMuted,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppThemeConstants.primary, size: 20),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close_rounded,
                            color: AppThemeConstants.textMuted, size: 18),
                        onPressed: onSearchClear,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Segmented pill filter + sort button
          Row(
            children: [
              Expanded(
                child: _SegmentedFilter(
                  selected: segment,
                  onChanged: onSegmentChanged,
                ),
              ),
              const SizedBox(width: 8),
              _SortIconButton(
                ascending: sortAsc,
                onTap: onSortTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentedFilter extends StatelessWidget {
  final _Segment selected;
  final ValueChanged<_Segment> onChanged;

  const _SegmentedFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(_R.pill + 4),
        border: Border.all(
          color: AppThemeConstants.primary.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _Segment.values.map((s) {
          final isSelected = s == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppThemeConstants.primary
                      : AppThemeConstants.transparent,
                  borderRadius: BorderRadius.circular(_R.pill),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppThemeConstants.primary
                                .withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      s.icon,
                      size: 16,
                      color: isSelected
                          ? AppThemeConstants.white
                          : AppThemeConstants.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppThemeConstants.white
                            : AppThemeConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SortIconButton extends StatelessWidget {
  final bool ascending;
  final VoidCallback onTap;

  const _SortIconButton({required this.ascending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        width: 58,
        decoration: BoxDecoration(
          color: AppThemeConstants.white,
          borderRadius: BorderRadius.circular(_R.pill),
          border: Border.all(
            color: AppThemeConstants.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Icon(
          ascending ? Icons.swap_vert_rounded : Icons.swap_vert_rounded,
          color: AppThemeConstants.primary,
          size: 20,
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

  String _initials() {
    final parts = student.studentName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts[0].isEmpty ? '؟' : parts[0][0];
    return '${parts[0][0]}${parts[1][0]}';
  }

  @override
  Widget build(BuildContext context) {
    final hasAssignment = student.hifzAssignment.isNotEmpty ||
        student.murajaAssignment.isNotEmpty;
    final hasPrevEval = student.previousHifzCompleted != null ||
        student.previousMurajaCompleted != null;
    final formattedDate = student.lastSessionDate != null
        ? DateFormat('dd MMM yyyy', 'ar').format(student.lastSessionDate!)
        : null;
    final hasPhoto = student.photoUrl != null && student.photoUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        // Even vertical wash: crisp white at the top fading to a soft cool
        // off-white at the bottom — gives gentle depth without the muddy
        // green corner a diagonal teal gradient produced.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppThemeConstants.white,
            Color(0xFFF1F7F6),
          ],
        ),
        borderRadius: BorderRadius.circular(_R.card),
        border: Border.all(
          color: AppThemeConstants.primary.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: AppThemeConstants.primary.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: AppThemeConstants.transparent,
        borderRadius: BorderRadius.circular(_R.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_R.card),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── TOP: Avatar + Name + Last session ───────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Gold-ringed avatar (52x52)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppThemeConstants.secondary.withValues(alpha: 0.85),
                            AppThemeConstants.primary.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppThemeConstants.primary.withValues(alpha: 0.85),
                        backgroundImage:
                            hasPhoto ? NetworkImage(student.photoUrl!) : null,
                        onBackgroundImageError: hasPhoto ? (_, __) {} : null,
                        child: hasPhoto
                            ? null
                            : Text(
                                _initials(),
                                style: const TextStyle(
                                  color: AppThemeConstants.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.studentName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppThemeConstants.textPrimary,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          // Consolidated meta line: sessions count · last session
                          Row(
                            children: [
                              const Icon(Icons.school_rounded,
                                  size: 13, color: AppThemeConstants.primary),
                              const SizedBox(width: 4),
                              Text(
                                '${student.sessionCount} جلسة',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppThemeConstants.primary,
                                ),
                              ),
                              if (formattedDate != null) ...[
                                const _MetaDot(),
                                const Icon(Icons.event_rounded,
                                    size: 13,
                                    color: AppThemeConstants.textMuted),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppThemeConstants.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (student.sessionRating > 0) ...[
                      const SizedBox(width: 8),
                      _RatingPill(rating: student.sessionRating),
                    ],
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_left_rounded,
                        size: 22, color: AppThemeConstants.grey300),
                  ],
                ),

                // ── MIDDLE: Assignments (emerald + gold only) ───────────
                if (hasAssignment) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppThemeConstants.transparent,
                          AppThemeConstants.secondary.withValues(alpha: 0.4),
                          AppThemeConstants.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (student.hifzAssignment.isNotEmpty)
                        _AssignmentChip(
                          icon: Icons.menu_book_rounded,
                          typeLabel: 'حفظ',
                          value: student.hifzAssignment,
                          color: AppThemeConstants.success,
                        ),
                      if (student.murajaAssignment.isNotEmpty)
                        _AssignmentChip(
                          icon: Icons.history_edu_rounded,
                          typeLabel: 'مراجعة',
                          value: student.murajaAssignment,
                          color: AppThemeConstants.secondary,
                        ),
                    ],
                  ),
                ],

                // ── BOTTOM: Previous evaluation ─────────────────────────
                if (hasPrevEval) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'السابقة',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppThemeConstants.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (student.previousHifzCompleted != null)
                        _EvalBadge(
                          label: 'حفظ ${student.previousHifzRating}/10',
                          completed: student.previousHifzCompleted!,
                        ),
                      if (student.previousMurajaCompleted != null)
                        _EvalBadge(
                          label: 'مراجعة ${student.previousMurajaRating}/10',
                          completed: student.previousMurajaCompleted!,
                        ),
                    ],
                  ),
                ],

                // ── Performance notes ───────────────────────────────────
                if (student.performanceNotes != null &&
                    student.performanceNotes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.secondaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(_R.pill),
                      border: Border(
                        right: BorderSide(
                          color: AppThemeConstants.secondary
                              .withValues(alpha: 0.6),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.format_quote_rounded,
                            size: 14, color: AppThemeConstants.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            student.performanceNotes!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppThemeConstants.textSecondary,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

// Small dot separator used inside the meta line.
class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 7),
      child: Icon(Icons.circle, size: 3, color: AppThemeConstants.textMuted),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final int rating;
  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    final color = rating >= 8
        ? AppThemeConstants.success
        : rating >= 5
            ? AppThemeConstants.secondary
            : AppThemeConstants.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(_R.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            '$rating',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _AssignmentChip extends StatelessWidget {
  final IconData icon;
  final String typeLabel;
  final String value;
  final Color color;
  const _AssignmentChip(
      {required this.icon,
      required this.typeLabel,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_R.pill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$typeLabel: ',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvalBadge extends StatelessWidget {
  final String label;
  final bool completed;
  const _EvalBadge({required this.label, required this.completed});

  @override
  Widget build(BuildContext context) {
    final color =
        completed ? AppThemeConstants.success : AppThemeConstants.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(_R.badge),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(5, (_) => _SkeletonCard()),
      ),
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
