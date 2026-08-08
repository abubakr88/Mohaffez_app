import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../providers/quran_local_providers.dart';
import '../../services/quran_local_store.dart';
import '../../shared/widgets/interactive_quran_page.dart';

class StudentInteractiveQuranScreen extends ConsumerWidget {
  const StudentInteractiveQuranScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('تعذر تحميل بيانات الطالب')),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text(ArabicLabels.pleaseLoginFirst)),
          );
        }
        final activeProfileAsync = ref.watch(activeStudentProfileProvider);
        final isParent = normalizeRole(user.role) == roleParent;
        if (isParent && activeProfileAsync.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = activeProfileAsync.valueOrNull;
        final profileId = profile?.isPersisted == true ? profile!.id : null;
        return _LocalQuranReader(
          key: ValueKey('${user.uid}:${profileId ?? 'self'}'),
          providerScope: (
            userId: user.uid,
            studentProfileId: profileId,
          ),
        );
      },
    );
  }
}

class _LocalQuranReader extends ConsumerStatefulWidget {
  const _LocalQuranReader({
    super.key,
    required this.providerScope,
  });

  final QuranLocalProviderScope providerScope;

  @override
  ConsumerState<_LocalQuranReader> createState() => _LocalQuranReaderState();
}

class _LocalQuranReaderState extends ConsumerState<_LocalQuranReader> {
  final InteractiveQuranController _readerController =
      InteractiveQuranController();

  QuranLocalStore? _store;
  QuranLocalProgress _progress = const QuranLocalProgress();
  List<CachedQuranSession> _sessions = const [];
  Timer? _saveDebounce;
  bool _loading = true;
  bool _wardExpanded = true;
  bool _reviewMode = false;
  bool _focusMode = false;
  int _currentPage = 1;
  int? _hifzTargetPage;
  int? _murajaTargetPage;
  QuranMistake? _focusedMistake;

  QuranLocalScope get _localScope =>
      quranLocalScopeFromProvider(widget.providerScope);

  List<QuranMistake> get _unreviewedMistakes => _sessions
      .expand(
        (session) => session.mistakes.where(
          (mistake) => !_progress.isMistakeReviewed(
            quranMistakeReviewKey(session.sessionId, mistake),
          ),
        ),
      )
      .toList();

  List<QuranMistake> get _activeReviewMistakes {
    final mistakes = <QuranMistake>[..._unreviewedMistakes];
    final focused = _focusedMistake;
    if (focused != null && !mistakes.contains(focused)) {
      mistakes.add(focused);
    }
    return mistakes;
  }

  List<int> get _reviewPages => _activeReviewMistakes
      .map((mistake) => mistake.pageNumber)
      .toSet()
      .toList()
    ..sort();

  CachedQuranSession? get _latestSession =>
      _sessions.isEmpty ? null : _sessions.first;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    final store = _store;
    if (store != null) {
      store.saveProgress(_localScope, _progress);
    }
    super.dispose();
  }

  Future<void> _loadLocalData() async {
    final store = await QuranLocalStore.create();
    final progress = store.loadProgress(_localScope);
    final sessions = store.loadSessions(_localScope);
    final latest = sessions.isEmpty ? null : sessions.first;
    final quranService = QuranService();
    final hifzTargetPage = latest?.hasHifz == true
        ? await quranService.findPageForAssignment(
            latest!.hifzAssignment!,
            fromAyah: latest.hifzFromAyah,
          )
        : null;
    final murajaTargetPage = latest?.hasMuraja == true
        ? await quranService.findPageForAssignment(
            latest!.murajaAssignment!,
            fromAyah: latest.murajaFromAyah,
          )
        : null;
    if (!mounted) return;
    setState(() {
      _store = store;
      _progress = progress;
      _sessions = sessions;
      _currentPage = progress.lastPage;
      _hifzTargetPage = hifzTargetPage;
      _murajaTargetPage = murajaTargetPage;
      _loading = false;
    });
  }

  void _recordPage(int page) {
    final updated = _progress.recordPage(page);
    setState(() {
      _currentPage = page;
      _progress = updated;
    });
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      await _store?.saveProgress(_localScope, _progress);
      if (!mounted) return;
      ref.invalidate(quranLocalProgressProvider(widget.providerScope));
    });
  }

  Future<void> _toggleBookmark() async {
    setState(() {
      _progress = _progress.toggleBookmark(_currentPage);
    });
    await _store?.saveProgress(_localScope, _progress);
    if (!mounted) return;
    ref.invalidate(quranLocalProgressProvider(widget.providerScope));
  }

  Future<void> _openAssignments() async {
    await context.push('/assignments');
    if (!mounted) return;
    await _loadLocalData();
  }

  Future<void> _openWard(
    String surahName,
    String? fromAyah,
    int? resolvedPage,
  ) async {
    final page = resolvedPage ??
        await QuranService().findPageForAssignment(
          surahName,
          fromAyah: fromAyah,
        );
    if (!mounted) return;
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر تحديد صفحة الورد تلقائيًا، اختر الموضع يدويًا.',
          ),
        ),
      );
      _readerController.openJumpSheet();
      return;
    }
    setState(() => _wardExpanded = false);
    _readerController.jumpToPage(page);
  }

  Future<void> _toggleMistakeReviewed(
    CachedQuranSession session,
    QuranMistake mistake,
  ) async {
    final key = quranMistakeReviewKey(session.sessionId, mistake);
    setState(() {
      _progress = _progress.toggleMistakeReviewed(key);
      if (_reviewMode && _unreviewedMistakes.isEmpty) {
        _reviewMode = false;
      }
    });
    await _store?.saveProgress(_localScope, _progress);
    if (!mounted) return;
    ref.invalidate(quranLocalProgressProvider(widget.providerScope));
  }

  Future<void> _clearTeacherNotes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('مسح البيانات المحلية؟'),
        content: const Text(
          'سيتم حذف الورد وملاحظات المعلمين المحفوظة على هذا الجهاز فقط.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store?.clearSessions(_localScope);
    if (!mounted) return;
    setState(() {
      _sessions = const [];
      _progress = _progress.clearReviewedMistakes();
      _hifzTargetPage = null;
      _murajaTargetPage = null;
      _focusedMistake = null;
      _reviewMode = false;
    });
    await _store?.saveProgress(_localScope, _progress);
    if (!mounted) return;
    ref.invalidate(quranLocalProgressProvider(widget.providerScope));
    ref.invalidate(quranCachedSessionsProvider(widget.providerScope));
  }

  void _jumpToMistake(QuranMistake mistake) {
    setState(() {
      _focusedMistake = mistake;
      _reviewMode = true;
    });
    _readerController.jumpToPage(mistake.pageNumber);
  }

  void _moveBetweenReviewPages(int delta) {
    final pages = _reviewPages;
    if (pages.isEmpty) return;
    var index = pages.indexOf(_currentPage);
    if (index < 0) {
      index = pages.indexWhere((page) => page > _currentPage);
      if (index < 0) index = pages.length - 1;
    }
    final targetIndex = (index + delta).clamp(0, pages.length - 1);
    _readerController.jumpToPage(pages[targetIndex]);
  }

  void _openTeacherNotes() {
    final sessions = _sessions.where((session) => session.hasMistakes).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _TeacherNotesSheet(
        sessions: sessions,
        reviewedMistakeKeys: _progress.reviewedMistakeKeys.toSet(),
        onMistakeTap: (mistake) {
          Navigator.pop(sheetContext);
          _jumpToMistake(mistake);
        },
        onToggleReviewed: _toggleMistakeReviewed,
        onOpenAssignments: () {
          Navigator.pop(sheetContext);
          _openAssignments();
        },
        onClear: () {
          Navigator.pop(sheetContext);
          _clearTeacherNotes();
        },
      ),
    );
  }

  void _openBookmarksAndRecent() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bookmarks_outlined),
                title: Text(
                  'العلامات وآخر الصفحات',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (_progress.bookmarkedPages.isEmpty)
                const ListTile(
                  title: Text('لا توجد صفحات محفوظة بعد'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _progress.bookmarkedPages
                      .map(
                        (page) => ActionChip(
                          avatar: const Icon(Icons.bookmark, size: 16),
                          label: Text('صفحة $page'),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _readerController.jumpToPage(page);
                          },
                        ),
                      )
                      .toList(),
                ),
              const Divider(height: 30),
              const Text(
                'آخر الصفحات',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _progress.recentPages
                    .map(
                      (page) => ActionChip(
                        label: Text('ص $page'),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _readerController.jumpToPage(page);
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final remainingMistakes = _unreviewedMistakes.length;
    final latest = _latestSession;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المصحف التفاعلي'),
          backgroundColor: AppThemeConstants.primary,
          actions: [
            _CountedAppBarButton(
              tooltip: 'ملاحظات المعلم',
              icon: Icons.rate_review_outlined,
              count: remainingMistakes,
              onPressed: _openTeacherNotes,
            ),
            IconButton(
              tooltip: 'العلامات وآخر الصفحات',
              onPressed: _openBookmarksAndRecent,
              icon: const Icon(Icons.bookmarks_outlined),
            ),
            IconButton(
              tooltip: _progress.isBookmarked(_currentPage)
                  ? 'إزالة العلامة'
                  : 'حفظ الصفحة',
              onPressed: _toggleBookmark,
              icon: Icon(
                _progress.isBookmarked(_currentPage)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
            ),
            IconButton(
              tooltip: _focusMode ? 'إظهار الأدوات' : 'وضع القراءة',
              onPressed: () => setState(() => _focusMode = !_focusMode),
              icon: Icon(
                _focusMode ? Icons.fullscreen_exit : Icons.fullscreen,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (!_focusMode)
              _LatestWardCard(
                session: latest,
                expanded: _wardExpanded,
                todayPages: _progress.todayPagesRead,
                dailyGoal: _progress.dailyGoalPages,
                streak: _progress.currentStreak,
                onToggle: () => setState(() => _wardExpanded = !_wardExpanded),
                onStart: _readerController.openJumpSheet,
                hifzTargetPage: _hifzTargetPage,
                murajaTargetPage: _murajaTargetPage,
                onOpenHifz: latest?.hasHifz == true
                    ? () => _openWard(
                          latest!.hifzAssignment!,
                          latest.hifzFromAyah,
                          _hifzTargetPage,
                        )
                    : null,
                onOpenMuraja: latest?.hasMuraja == true
                    ? () => _openWard(
                          latest!.murajaAssignment!,
                          latest.murajaFromAyah,
                          _murajaTargetPage,
                        )
                    : null,
                onOpenAssignments: _openAssignments,
              ),
            if (_reviewMode)
              _ReviewModeBar(
                currentPage: _currentPage,
                pages: _reviewPages,
                onPrevious: () => _moveBetweenReviewPages(-1),
                onNext: () => _moveBetweenReviewPages(1),
                onExit: () => setState(() => _reviewMode = false),
              ),
            Expanded(
              child: InteractiveQuranPage(
                pageNumber: _currentPage,
                controller: _readerController,
                existingMistakes: _reviewMode
                    ? _activeReviewMistakes
                    : const <QuranMistake>[],
                onMistakeAdded: (_) {},
                isEditable: false,
                showControls: !_focusMode,
                onPageChanged: _recordPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestWardCard extends StatelessWidget {
  const _LatestWardCard({
    required this.session,
    required this.expanded,
    required this.todayPages,
    required this.dailyGoal,
    required this.streak,
    required this.onToggle,
    required this.onStart,
    required this.hifzTargetPage,
    required this.murajaTargetPage,
    required this.onOpenHifz,
    required this.onOpenMuraja,
    required this.onOpenAssignments,
  });

  final CachedQuranSession? session;
  final bool expanded;
  final int todayPages;
  final int dailyGoal;
  final int streak;
  final VoidCallback onToggle;
  final VoidCallback onStart;
  final int? hifzTargetPage;
  final int? murajaTargetPage;
  final VoidCallback? onOpenHifz;
  final VoidCallback? onOpenMuraja;
  final VoidCallback onOpenAssignments;

  @override
  Widget build(BuildContext context) {
    final latest = session;
    return Material(
      color: const Color(0xFFF8FAF8),
      child: InkWell(
        onTap: onToggle,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.assignment_turned_in_outlined,
                      color: AppThemeConstants.success,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ورد آخر جلسة',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _ProgressChip(
                      label: '$todayPages/$dailyGoal صفحة اليوم',
                      icon: Icons.local_fire_department_outlined,
                    ),
                    if (streak > 0) ...[
                      const SizedBox(width: 6),
                      _ProgressChip(
                        label: '$streak يوم',
                        icon: Icons.bolt,
                      ),
                    ],
                    Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(height: 8),
                  if (latest == null)
                    _NoLocalWard(onOpenAssignments: onOpenAssignments)
                  else ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${latest.mohaffezName} • '
                        '${DateFormat('d MMM yyyy', 'ar').format(latest.sessionDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppThemeConstants.textSecondary,
                        ),
                      ),
                    ),
                    if (!latest.hasWard) ...[
                      const SizedBox(height: 8),
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'لم يحدد المعلم وردًا في آخر جلسة.',
                          style: TextStyle(color: AppThemeConstants.grey600),
                        ),
                      ),
                    ],
                    if (latest.hasHifz) ...[
                      const SizedBox(height: 8),
                      _WardItem(
                        icon: Icons.auto_stories,
                        title: 'الحفظ الجديد',
                        content: latest.hifzAssignment!,
                        fromAyah: latest.hifzFromAyah,
                        toAyah: latest.hifzToAyah,
                        targetPage: hifzTargetPage,
                        color: AppThemeConstants.success,
                        onTap: onOpenHifz!,
                      ),
                    ],
                    if (latest.hasMuraja) ...[
                      const SizedBox(height: 8),
                      _WardItem(
                        icon: Icons.refresh,
                        title: 'ورد المراجعة',
                        content: latest.murajaAssignment!,
                        fromAyah: latest.murajaFromAyah,
                        toAyah: latest.murajaToAyah,
                        targetPage: murajaTargetPage,
                        color: AppThemeConstants.accentBlueDark,
                        onTap: onOpenMuraja!,
                      ),
                    ],
                    if (latest.hasWard) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onStart,
                          icon: const Icon(Icons.edit_location_alt_outlined),
                          label: const Text('اختيار موضع آخر يدويًا'),
                        ),
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WardItem extends StatelessWidget {
  const _WardItem({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
    required this.onTap,
    this.fromAyah,
    this.toAyah,
    this.targetPage,
  });

  final IconData icon;
  final String title;
  final String content;
  final Color color;
  final VoidCallback onTap;
  final String? fromAyah;
  final String? toAyah;
  final int? targetPage;

  @override
  Widget build(BuildContext context) {
    final hasRange = fromAyah != null || toAyah != null;
    return Semantics(
      button: true,
      label: 'الانتقال إلى $title',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (hasRange)
                      Text(
                        'من آية ${fromAyah ?? '؟'} إلى آية ${toAyah ?? '؟'}',
                        style: TextStyle(fontSize: 11, color: color),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      targetPage == null
                          ? 'اضغط للانتقال إلى موضع الورد'
                          : 'صفحة $targetPage • اضغط للانتقال',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 15,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TeacherNotesFilter { pending, all, reviewed }

class _TeacherNotesSheet extends StatefulWidget {
  const _TeacherNotesSheet({
    required this.sessions,
    required this.reviewedMistakeKeys,
    required this.onMistakeTap,
    required this.onToggleReviewed,
    required this.onOpenAssignments,
    required this.onClear,
  });

  final List<CachedQuranSession> sessions;
  final Set<String> reviewedMistakeKeys;
  final ValueChanged<QuranMistake> onMistakeTap;
  final Future<void> Function(CachedQuranSession, QuranMistake)
      onToggleReviewed;
  final VoidCallback onOpenAssignments;
  final VoidCallback onClear;

  @override
  State<_TeacherNotesSheet> createState() => _TeacherNotesSheetState();
}

class _TeacherNotesSheetState extends State<_TeacherNotesSheet> {
  late final Set<String> _reviewedMistakeKeys = <String>{
    ...widget.reviewedMistakeKeys
  };
  _TeacherNotesFilter _filter = _TeacherNotesFilter.pending;

  int get _totalMistakes =>
      widget.sessions.fold(0, (sum, session) => sum + session.mistakes.length);

  int get _reviewedCount => widget.sessions.fold(
        0,
        (sum, session) =>
            sum +
            session.mistakes
                .where(
                  (mistake) => _reviewedMistakeKeys.contains(
                    quranMistakeReviewKey(session.sessionId, mistake),
                  ),
                )
                .length,
      );

  List<QuranMistake> _visibleMistakes(CachedQuranSession session) {
    return session.mistakes.where((mistake) {
      final reviewed = _reviewedMistakeKeys.contains(
        quranMistakeReviewKey(session.sessionId, mistake),
      );
      return switch (_filter) {
        _TeacherNotesFilter.pending => !reviewed,
        _TeacherNotesFilter.all => true,
        _TeacherNotesFilter.reviewed => reviewed,
      };
    }).toList();
  }

  Future<void> _toggle(
    CachedQuranSession session,
    QuranMistake mistake,
  ) async {
    final key = quranMistakeReviewKey(session.sessionId, mistake);
    setState(() {
      if (!_reviewedMistakeKeys.add(key)) {
        _reviewedMistakeKeys.remove(key);
      }
    });
    await widget.onToggleReviewed(session, mistake);
  }

  @override
  Widget build(BuildContext context) {
    final latestCachedAt = widget.sessions.isEmpty
        ? null
        : widget.sessions
            .map((session) => session.cachedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
    final visibleSessions = widget.sessions
        .where((session) => _visibleMistakes(session).isNotEmpty)
        .toList();
    final remaining = _totalMistakes - _reviewedCount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.95,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppThemeConstants.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.rate_review_outlined,
                    color: AppThemeConstants.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملاحظات المعلم • تبقى $remaining من $_totalMistakes',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (latestCachedAt != null)
                          Text(
                            'آخر تحديث على هذا الجهاز: '
                            '${DateFormat('d MMM، h:mm a', 'ar').format(latestCachedAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppThemeConstants.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحديث من شاشة الواجبات',
                    onPressed: widget.onOpenAssignments,
                    icon: const Icon(Icons.sync),
                  ),
                  IconButton(
                    tooltip: 'مسح البيانات المحلية',
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('غير مُراجع ($remaining)'),
                    selected: _filter == _TeacherNotesFilter.pending,
                    onSelected: (_) =>
                        setState(() => _filter = _TeacherNotesFilter.pending),
                  ),
                  ChoiceChip(
                    label: Text('الكل ($_totalMistakes)'),
                    selected: _filter == _TeacherNotesFilter.all,
                    onSelected: (_) =>
                        setState(() => _filter = _TeacherNotesFilter.all),
                  ),
                  ChoiceChip(
                    label: Text('تمت مراجعته ($_reviewedCount)'),
                    selected: _filter == _TeacherNotesFilter.reviewed,
                    onSelected: (_) =>
                        setState(() => _filter = _TeacherNotesFilter.reviewed),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.sessions.isEmpty
                  ? _EmptyTeacherNotes(
                      onOpenAssignments: widget.onOpenAssignments,
                    )
                  : visibleSessions.isEmpty
                      ? Center(
                          child: Text(
                            _filter == _TeacherNotesFilter.pending
                                ? 'أحسنت، راجعت كل ملاحظات المعلم.'
                                : 'لا توجد ملاحظات في هذا التصنيف.',
                            style: const TextStyle(
                              color: AppThemeConstants.grey600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          itemCount: visibleSessions.length,
                          itemBuilder: (_, index) {
                            final session = visibleSessions[index];
                            return _TeacherSessionNotesTile(
                              session: session,
                              mistakes: _visibleMistakes(session),
                              reviewedMistakeKeys: _reviewedMistakeKeys,
                              onMistakeTap: widget.onMistakeTap,
                              onToggleReviewed: (mistake) =>
                                  _toggle(session, mistake),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherSessionNotesTile extends StatelessWidget {
  const _TeacherSessionNotesTile({
    required this.session,
    required this.mistakes,
    required this.reviewedMistakeKeys,
    required this.onMistakeTap,
    required this.onToggleReviewed,
  });

  final CachedQuranSession session;
  final List<QuranMistake> mistakes;
  final Set<String> reviewedMistakeKeys;
  final ValueChanged<QuranMistake> onMistakeTap;
  final ValueChanged<QuranMistake> onToggleReviewed;

  @override
  Widget build(BuildContext context) {
    final counts = <MistakeType, int>{};
    for (final mistake in mistakes) {
      counts[mistake.type] = (counts[mistake.type] ?? 0) + 1;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Text(session.mohaffezName.characters.first),
        ),
        title: Text(
          session.mohaffezName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${DateFormat('d MMM yyyy', 'ar').format(session.sessionDate)}'
          ' • ${mistakes.length} ملاحظة',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: counts.entries
                  .map(
                    (entry) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${entry.key.arabicLabel} (${entry.value})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          ...mistakes.map(
            (mistake) {
              final reviewed = reviewedMistakeKeys.contains(
                quranMistakeReviewKey(session.sessionId, mistake),
              );
              return ListTile(
                leading: Checkbox(
                  value: reviewed,
                  onChanged: (_) => onToggleReviewed(mistake),
                ),
                title: Text(
                  '${mistake.type.arabicLabel} • صفحة ${mistake.pageNumber}',
                  style: TextStyle(
                    decoration: reviewed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                subtitle: Text(
                  [
                    if (mistake.wordText?.isNotEmpty == true) mistake.wordText!,
                    if (mistake.correctionNote?.isNotEmpty == true)
                      mistake.correctionNote!,
                  ].join(' — '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_back_ios_new, size: 15),
                onTap: () => onMistakeTap(mistake),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewModeBar extends StatelessWidget {
  const _ReviewModeBar({
    required this.currentPage,
    required this.pages,
    required this.onPrevious,
    required this.onNext,
    required this.onExit,
  });

  final int currentPage;
  final List<int> pages;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final index = pages.indexOf(currentPage);
    return Container(
      color: AppThemeConstants.warningLight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.rate_review, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'مراجعة الملاحظات'
              '${index >= 0 ? ' (${index + 1}/${pages.length})' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'الملاحظة السابقة',
            onPressed: pages.isEmpty ? null : onPrevious,
            icon: const Icon(Icons.arrow_forward),
          ),
          IconButton(
            tooltip: 'الملاحظة التالية',
            onPressed: pages.isEmpty ? null : onNext,
            icon: const Icon(Icons.arrow_back),
          ),
          TextButton(onPressed: onExit, child: const Text('إنهاء')),
        ],
      ),
    );
  }
}

class _CountedAppBarButton extends StatelessWidget {
  const _CountedAppBarButton({
    required this.tooltip,
    required this.icon,
    required this.count,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
        if (count > 0)
          PositionedDirectional(
            top: 5,
            end: 3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppThemeConstants.warning,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppThemeConstants.successLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppThemeConstants.successDark),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _NoLocalWard extends StatelessWidget {
  const _NoLocalWard({required this.onOpenAssignments});

  final VoidCallback onOpenAssignments;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'افتح الواجبات لتحديث وردك وملاحظات المعلم على هذا الجهاز.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: onOpenAssignments,
          child: const Text('فتح الواجبات'),
        ),
      ],
    );
  }
}

class _EmptyTeacherNotes extends StatelessWidget {
  const _EmptyTeacherNotes({required this.onOpenAssignments});

  final VoidCallback onOpenAssignments;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.rate_review_outlined,
              size: 56,
              color: AppThemeConstants.grey400,
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد ملاحظات محفوظة على هذا الجهاز',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'افتح شاشة الواجبات ليتم حفظ آخر الجلسات المحمّلة محليًا.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppThemeConstants.grey600),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onOpenAssignments,
              child: const Text('فتح الواجبات'),
            ),
          ],
        ),
      ),
    );
  }
}
