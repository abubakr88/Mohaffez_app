// lib/shared/widgets/interactive_quran_page.dart

import 'package:flutter/material.dart';
import '../../models/quran_mistake_model.dart';
import '../../services/quran_service.dart';
import 'quran/mistake_detail_dialog.dart';
import 'quran/mistake_type_selector.dart';
import 'quran/quran_page_image.dart';

class InteractiveQuranPage extends StatefulWidget {
  final int pageNumber;
  final List<QuranMistake> existingMistakes;
  final Function(QuranMistake) onMistakeAdded;
  final bool isEditable;
  final Function(int)? onPageChanged;

  const InteractiveQuranPage({
    super.key,
    required this.pageNumber,
    this.existingMistakes = const [],
    required this.onMistakeAdded,
    this.isEditable = true,
    this.onPageChanged,
  });

  @override
  State<InteractiveQuranPage> createState() => _InteractiveQuranPageState();
}

class _InteractiveQuranPageState extends State<InteractiveQuranPage> {
  MistakeType selectedMistakeType = MistakeType.tajweed;
  late int currentPage;
  Map<String, dynamic>? pageInfo;
  bool isLoading = true;

  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    currentPage = widget.pageNumber;
    _loadPageData();
  }

  Future<void> _loadPageData() async {
    setState(() => isLoading = true);
    try {
      final info = await QuranService().getPageInfo(currentPage);
      if (!mounted) return;
      setState(() {
        pageInfo = info;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading page data: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void _changePage(int newPage) {
    if (newPage < 1 || newPage > QuranService.totalPages) return;
    setState(() => currentPage = newPage);
    widget.onPageChanged?.call(newPage);
    _loadPageData();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // JUMP SHEET
  // ─────────────────────────────────────────────────────────────────────────────

  void _openJumpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JumpToSheet(
        currentPage: currentPage,
        onPageSelected: (page) {
          Navigator.pop(context);
          _changePage(page);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (widget.isEditable) _buildMistakeTypeSelector(),
        Expanded(
          child: _buildQuranPageImage(),
        ),
        if (_hasAnyComments()) _buildCommentLegend(),
        _buildPageNavigation(),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // QURAN PAGE IMAGE
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildQuranPageImage() {
    return QuranPageImage(
      imageKey: _imageKey,
      currentPage: currentPage,
      pageInfo: pageInfo,
      mistakes: widget.existingMistakes
          .where((m) => m.pageNumber == currentPage)
          .toList(),
      onTapDown: _handleTapDown,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAP HANDLER
  // ─────────────────────────────────────────────────────────────────────────────

  void _handleTapDown(TapDownDetails details) {
    final RenderBox? box =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(details.globalPosition);
    final size = box.size;

    final xPosition = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final yPosition = (localPosition.dy / size.height).clamp(0.0, 1.0);

    final tappedMistake = _findTappedMistake(xPosition, yPosition);
    if (tappedMistake != null) {
      _showMistakeDetails(tappedMistake);
      return;
    }

    if (!widget.isEditable) return;
    _showMistakeDialog(xPosition, yPosition);
  }

  QuranMistake? _findTappedMistake(double x, double y) {
    const threshold = 0.03;
    for (final mistake
        in widget.existingMistakes.where((m) => m.pageNumber == currentPage)) {
      final dx = (mistake.xPosition - x).abs();
      final dy = (mistake.yPosition - y).abs();
      if (dx <= threshold && dy <= threshold) {
        return mistake;
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ADD MISTAKE DIALOG
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _showMistakeDialog(double x, double y) async {
    if (pageInfo == null) return;

    final TextEditingController noteController = TextEditingController();
    final TextEditingController wordController = TextEditingController();

    final verses = pageInfo!['verses'] as List<dynamic>? ?? [];
    if (verses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد آيات متاحة لهذه الصفحة')),
      );
      return;
    }

    int selectedAyah = verses.first['verse'] ?? 1;
    int selectedSurah = verses.first['surah'] ?? 1;
    MistakeType dialogMistakeType = selectedMistakeType;

    final result = await showDialog<QuranMistake>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('تحديد الخطأ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'رقم الآية'),
                    initialValue: selectedAyah,
                    items: verses.map((verse) {
                      final ayahNum = verse['verse'] as int;
                      return DropdownMenuItem(
                        value: ayahNum,
                        child: Text('آية $ayahNum'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedAyah = val;
                          final verse = verses.firstWhere((v) => v['verse'] == val);
                          selectedSurah = verse['surah'] as int;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: wordController,
                    decoration: const InputDecoration(
                      labelText: 'الكلمة (اختياري)',
                      hintText: 'مثال: ٱلْحَمْدُ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MistakeType>(
                    decoration: const InputDecoration(labelText: 'نوع الخطأ'),
                    initialValue: dialogMistakeType,
                    items: MistakeType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(_getMistakeIcon(type),
                                size: 16, color: _getMistakeColor(type)),
                            const SizedBox(width: 8),
                            Text(_getMistakeTypeLabel(type)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => dialogMistakeType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'تعليق التصحيح',
                      hintText: 'اشرح الخطأ وكيفية التصحيح...',
                      helperText: 'إضافة تعليق ستظهر علامة زرقاء 🔵 على الآية',
                      helperStyle: TextStyle(color: Colors.blue.shade700),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final mistake = QuranMistake(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    pageNumber: currentPage,
                    surahNumber: selectedSurah,
                    ayahNumber: selectedAyah,
                    type: dialogMistakeType,
                    xPosition: x,
                    yPosition: y,
                    wordText: wordController.text.trim().isEmpty
                        ? null
                        : wordController.text.trim(),
                    correctionNote: noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim(),
                    markedAt: DateTime.now(),
                  );
                  Navigator.pop(ctx, mistake);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      widget.onMistakeAdded(result);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MISTAKE MARKERS
  // ─────────────────────────────────────────────────────────────────────────────

  void _showMistakeDetails(QuranMistake mistake) {
    showMistakeDetailDialog(context, mistake, isEditable: widget.isEditable);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MISTAKE TYPE SELECTOR
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildMistakeTypeSelector() {
    return MistakeTypeSelector(
      selectedType: selectedMistakeType,
      onChanged: (type) => setState(() => selectedMistakeType = type),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // COMMENT LEGEND
  // ─────────────────────────────────────────────────────────────────────────────

  bool _hasAnyComments() {
    return widget.existingMistakes
        .where((m) => m.pageNumber == currentPage)
        .any((m) => m.correctionNote != null && m.correctionNote!.isNotEmpty);
  }

  Widget _buildCommentLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble, size: 7, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            'العلامة الزرقاء = يوجد تعليق من المعلم — اضغط على العلامة لعرضه',
            style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PAGE NAVIGATION  (with jump button)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPageNavigation() {
    final mistakesOnPage = widget.existingMistakes
        .where((m) => m.pageNumber == currentPage)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Previous page (→ RTL)
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed:
                currentPage > 1 ? () => _changePage(currentPage - 1) : null,
            tooltip: 'الصفحة السابقة',
          ),

          // ── Center: page info + jump button ──────────────────────────
          GestureDetector(
            onTap: _openJumpSheet,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page number + jump icon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book,
                          size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 5),
                      Text(
                        'صفحة $currentPage',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.keyboard_arrow_up,
                          size: 18, color: Colors.grey.shade500),
                    ],
                  ),
                  // Juz label
                  if (pageInfo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'الجزء ${pageInfo!['juz']}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                  // Mistakes badge
                  if (mistakesOnPage > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        '$mistakesOnPage '
                        '${mistakesOnPage == 1 ? 'ملاحظة' : 'ملاحظات'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Next page (← RTL)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: currentPage < QuranService.totalPages
                ? () => _changePage(currentPage + 1)
                : null,
            tooltip: 'الصفحة التالية',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MISTAKE TYPE HELPERS
  // ─────────────────────────────────────────────────────────────────────────────

  String _getMistakeTypeLabel(MistakeType type) {
    switch (type) {
      case MistakeType.tajweed:       return 'خطأ تجويد';
      case MistakeType.pronunciation: return 'خطأ نطق';
      case MistakeType.reading:       return 'قراءة خاطئة';
      case MistakeType.skip:          return 'تجاوز';
      case MistakeType.addition:      return 'زيادة';
      case MistakeType.other:         return 'أخرى';
    }
  }

  Color _getMistakeColor(MistakeType type) {
    switch (type) {
      case MistakeType.tajweed:       return Colors.orange;
      case MistakeType.pronunciation: return Colors.red;
      case MistakeType.reading:       return Colors.purple;
      case MistakeType.skip:          return Colors.blue;
      case MistakeType.addition:      return Colors.green;
      case MistakeType.other:         return Colors.grey;
    }
  }

  IconData _getMistakeIcon(MistakeType type) {
    switch (type) {
      case MistakeType.tajweed:       return Icons.auto_fix_high;
      case MistakeType.pronunciation: return Icons.record_voice_over;
      case MistakeType.reading:       return Icons.error_outline;
      case MistakeType.skip:          return Icons.fast_forward;
      case MistakeType.addition:      return Icons.add_circle_outline;
      case MistakeType.other:         return Icons.help_outline;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// JUMP-TO BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _JumpToSheet extends StatefulWidget {
  final int currentPage;
  final void Function(int page) onPageSelected;

  const _JumpToSheet({
    required this.currentPage,
    required this.onPageSelected,
  });

  @override
  State<_JumpToSheet> createState() => _JumpToSheetState();
}

class _JumpToSheetState extends State<_JumpToSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim()),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Resolve which Surah the current page is inside (for highlight)
  int _currentSurahNumber() {
    int surah = 1;
    for (final entry in QuranService.surahStartPages.entries) {
      if (entry.value <= widget.currentPage) surah = entry.key;
    }
    return surah;
  }

  // Resolve which Juz the current page is inside (for highlight)
  int _currentJuzNumber() {
    int juz = 1;
    for (final entry in QuranService.juzStartPages.entries) {
      if (entry.value <= widget.currentPage) juz = entry.key;
    }
    return juz;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.45,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle ────────────────────────────────────────────────
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Title ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.menu_book,
                        color: Colors.green.shade700, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'الانتقال إلى',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    // Current position chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'ص ${widget.currentPage}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Search (Surah tab only) ────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن سورة...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Tabs ──────────────────────────────────────────────────
              TabBar(
                controller: _tab,
                labelColor: Colors.green.shade700,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.green.shade700,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.format_list_numbered, size: 16),
                        SizedBox(width: 6),
                        Text('السور'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book, size: 16),
                        SizedBox(width: 6),
                        Text('الأجزاء'),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),

              // ── Tab content ───────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _SurahList(
                      query: _query,
                      currentSurah: _currentSurahNumber(),
                      scrollCtrl: scrollCtrl,
                      onSelected: widget.onPageSelected,
                    ),
                    _JuzList(
                      currentJuz: _currentJuzNumber(),
                      scrollCtrl: scrollCtrl,
                      onSelected: widget.onPageSelected,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SURAH LIST TAB
// ═════════════════════════════════════════════════════════════════════════════

class _SurahList extends StatelessWidget {
  final String query;
  final int currentSurah;
  final ScrollController scrollCtrl;
  final void Function(int page) onSelected;

  const _SurahList({
    required this.query,
    required this.currentSurah,
    required this.scrollCtrl,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final entries = QuranService.surahNames.entries
        .where((e) => query.isEmpty || e.value.contains(query))
        .toList();

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'لا توجد نتائج لـ "$query"',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: scrollCtrl,
      itemCount: entries.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 60, endIndent: 16),
      itemBuilder: (_, i) {
        final surahNum = entries[i].key;
        final name = entries[i].value;
        final page = QuranService.surahStartPages[surahNum]!;
        final isCurrent = surahNum == currentSurah;

        return Material(
          color: isCurrent ? Colors.green.shade50 : Colors.transparent,
          child: InkWell(
            onTap: () => onSelected(page),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Surah number circle
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Colors.green.shade600
                          : Colors.green.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent
                            ? Colors.green.shade600
                            : Colors.green.shade200,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$surahNum',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isCurrent
                            ? Colors.white
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Surah name
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 16,
                        color: isCurrent
                            ? Colors.green.shade800
                            : Colors.black87,
                      ),
                    ),
                  ),

                  // Current indicator
                  if (isCurrent) ...[
                    Icon(Icons.location_on,
                        size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                  ],

                  // Page badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'ص $page',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrent
                            ? Colors.green.shade800
                            : Colors.grey.shade600,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// JUZ GRID TAB
// ═════════════════════════════════════════════════════════════════════════════

class _JuzList extends StatelessWidget {
  final int currentJuz;
  final ScrollController scrollCtrl;
  final void Function(int page) onSelected;

  const _JuzList({
    required this.currentJuz,
    required this.scrollCtrl,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: 30,
      itemBuilder: (_, i) {
        final juzNum = i + 1;
        final page = QuranService.juzStartPages[juzNum]!;
        final isCurrent = juzNum == currentJuz;

        return GestureDetector(
          onTap: () => onSelected(page),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isCurrent ? Colors.green.shade600 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCurrent
                    ? Colors.green.shade700
                    : Colors.green.shade200,
                width: isCurrent ? 2 : 1,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCurrent ? Icons.location_on : Icons.book_outlined,
                  color: isCurrent ? Colors.white : Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(height: 5),
                Text(
                  'الجزء $juzNum',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isCurrent ? Colors.white : Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ص $page',
                  style: TextStyle(
                    fontSize: 11,
                    color: isCurrent
                        ? Colors.green.shade100
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}



