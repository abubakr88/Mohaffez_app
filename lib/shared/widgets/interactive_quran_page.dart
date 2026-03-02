// lib/shared/widgets/interactive_quran_page.dart

import 'package:flutter/material.dart';
import '../../models/quran_mistake_model.dart';
import '../../services/quran_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  // GlobalKey for the image container to get accurate dimensions
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
      setState(() {
        pageInfo = info;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading page data: $e');
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
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Mistake type selector — teacher only
        if (widget.isEditable) _buildMistakeTypeSelector(),

        // Quran page with tap detection
        Expanded(
          child: GestureDetector(
            onTapDown: widget.isEditable ? _handleTapDown : null,
            child: Stack(
              children: [
                _buildQuranPageImage(),
                ..._buildMistakeMarkers(),
              ],
            ),
          ),
        ),

        // Comment legend — only when there are mistakes with comments
        if (_hasAnyComments()) _buildCommentLegend(),

        // Page navigation
        _buildPageNavigation(),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // QURAN PAGE IMAGE
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildQuranPageImage() {
    return Container(
      key: _imageKey,
      color: const Color(0xFFF5F3E8),
      child: Center(
        child: CachedNetworkImage(
          imageUrl: QuranService().getPageImageUrl(currentPage),
          fit: BoxFit.contain,
          placeholder: (context, url) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('تحميل صفحة $currentPage...'),
            ],
          ),
          errorWidget: (context, url, error) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.menu_book, color: Colors.grey, size: 64),
                const SizedBox(height: 16),
                Text(
                  'صفحة $currentPage',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'الجزء ${pageInfo?['juz'] ?? ''}',
                  style:
                      TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                const Text(
                  'تأكد من الاتصال بالإنترنت',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            );
          },
        ),
      ),
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

    _showMistakeDialog(xPosition, yPosition);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ADD MISTAKE DIALOG  (teacher)
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('تحديد الخطأ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ayah selector
                  DropdownButtonFormField<int>(
                    decoration:
                        const InputDecoration(labelText: 'رقم الآية'),
                    value: selectedAyah,
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
                          final verse = verses
                              .firstWhere((v) => v['verse'] == val);
                          selectedSurah = verse['surah'] as int;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Word text (optional)
                  TextField(
                    controller: wordController,
                    decoration: const InputDecoration(
                      labelText: 'الكلمة (اختياري)',
                      hintText: 'مثال: ٱلْحَمْدُ',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mistake type
                  DropdownButtonFormField<MistakeType>(
                    decoration:
                        const InputDecoration(labelText: 'نوع الخطأ'),
                    value: dialogMistakeType,
                    items: MistakeType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(_getMistakeIcon(type),
                                size: 16,
                                color: _getMistakeColor(type)),
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

                  // Correction note — hint emphasises it will appear as blue badge
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'تعليق التصحيح',
                      hintText: 'اشرح الخطأ وكيفية التصحيح...',
                      helperText:
                          'إضافة تعليق ستظهر علامة زرقاء 🔵 على الآية',
                      helperStyle:
                          TextStyle(color: Colors.blue.shade700),
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
                    id: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(),
                    pageNumber: currentPage,
                    surahNumber: selectedSurah,
                    ayahNumber: selectedAyah,
                    type: dialogMistakeType,
                    xPosition: x,
                    yPosition: y,
                    wordText:
                        wordController.text.trim().isEmpty
                            ? null
                            : wordController.text.trim(),
                    correctionNote:
                        noteController.text.trim().isEmpty
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
  // MISTAKE MARKERS  (with comment badge)
  // ─────────────────────────────────────────────────────────────────────────────

  List<Widget> _buildMistakeMarkers() {
    // Use the image container's size instead of screen size
    final RenderBox? box =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    final Size size = box?.size ?? MediaQuery.of(context).size;

    return widget.existingMistakes
        .where((m) => m.pageNumber == currentPage)
        .map((mistake) {
      final hasComment = mistake.correctionNote != null &&
          mistake.correctionNote!.isNotEmpty;

      // Clamp coordinates to [0..1] and center marker (32px / 2 = 16)
      // xPosition/yPosition are non-nullable doubles, clamp returns double
      final double xPos = mistake.xPosition.clamp(0.0, 1.0);
      final double yPos = mistake.yPosition.clamp(0.0, 1.0);
      final x = xPos * size.width - 16;
      final y = yPos * size.height - 16;

      return Positioned(
        left: x,
        top: y,
        child: GestureDetector(
          onTap: () => _showMistakeDetails(mistake),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Main mistake circle ────────────────────────────────────
              Tooltip(
                message: _getMistakeTypeLabel(mistake.type),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getMistakeColor(mistake.type)
                        .withOpacity(0.85),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getMistakeIcon(mistake.type),
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),

              // ── Blue comment badge — only when correctionNote exists ──
              if (hasComment)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIEW MISTAKE DETAILS DIALOG  (teacher + student read-only)
  // ─────────────────────────────────────────────────────────────────────────────

  void _showMistakeDetails(QuranMistake mistake) {
    final hasComment = mistake.correctionNote != null &&
        mistake.correctionNote!.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

          // ── Title: type badge ──────────────────────────────────────────
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getMistakeColor(mistake.type).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getMistakeIcon(mistake.type),
                  color: _getMistakeColor(mistake.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getMistakeTypeLabel(mistake.type),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getMistakeColor(mistake.type),
                  ),
                ),
              ),
            ],
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Location row ─────────────────────────────────────────
              _detailRow(Icons.menu_book, 'الصفحة',
                  '${mistake.pageNumber}'),
              _detailRow(Icons.format_list_numbered, 'الآية',
                  '${mistake.ayahNumber}'),

              // ── Word text ────────────────────────────────────────────
              if (mistake.wordText != null &&
                  mistake.wordText!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'الكلمة / الموضع',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    mistake.wordText!,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              // ── Teacher comment ──────────────────────────────────────
              if (hasComment) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.chat_bubble,
                        size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'تعليق المعلم',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    mistake.correctionNote!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade900,
                      height: 1.6,
                    ),
                  ),
                ),
              ],

              // ── No comment hint (teacher view only) ──────────────────
              if (!hasComment && widget.isEditable) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(
                      'لا يوجد تعليق لهذا الخطأ',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ],
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MISTAKE TYPE SELECTOR  (teacher toolbar)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildMistakeTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: MistakeType.values.map((type) {
            final isSelected = selectedMistakeType == type;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                avatar: Icon(
                  _getMistakeIcon(type),
                  size: 16,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                label: Text(_getMistakeTypeLabel(type)),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => selectedMistakeType = type);
                },
                selectedColor: _getMistakeColor(type),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // COMMENT LEGEND
  // ─────────────────────────────────────────────────────────────────────────────

  bool _hasAnyComments() {
    return widget.existingMistakes
        .where((m) => m.pageNumber == currentPage)
        .any((m) =>
            m.correctionNote != null && m.correctionNote!.isNotEmpty);
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
  // PAGE NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPageNavigation() {
    final mistakesOnPage = widget.existingMistakes
        .where((m) => m.pageNumber == currentPage)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous page (→ in RTL = previous)
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: currentPage > 1
                ? () => _changePage(currentPage - 1)
                : null,
            tooltip: 'الصفحة السابقة',
          ),

          // Page info + mistake count badge
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'صفحة $currentPage',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (pageInfo != null)
                Text(
                  'الجزء ${pageInfo!['juz']}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              if (mistakesOnPage > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    '$mistakesOnPage ${mistakesOnPage == 1 ? 'ملاحظة' : 'ملاحظات'}',
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

          // Next page (← in RTL = next)
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
  // DIALOG DETAIL ROW HELPER
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
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
      case MistakeType.tajweed:
        return 'خطأ تجويد';
      case MistakeType.pronunciation:
        return 'خطأ نطق';
      case MistakeType.reading:
        return 'قراءة خاطئة';
      case MistakeType.skip:
        return 'تجاوز';
      case MistakeType.addition:
        return 'زيادة';
      case MistakeType.other:
        return 'أخرى';
      default:
        return 'غير محدد';
    }
  }

  Color _getMistakeColor(MistakeType type) {
    switch (type) {
      case MistakeType.tajweed:
        return Colors.orange;
      case MistakeType.pronunciation:
        return Colors.red;
      case MistakeType.reading:
        return Colors.purple;
      case MistakeType.skip:
        return Colors.blue;
      case MistakeType.addition:
        return Colors.green;
      case MistakeType.other:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getMistakeIcon(MistakeType type) {
    switch (type) {
      case MistakeType.tajweed:
        return Icons.auto_fix_high;
      case MistakeType.pronunciation:
        return Icons.record_voice_over;
      case MistakeType.reading:
        return Icons.error_outline;
      case MistakeType.skip:
        return Icons.fast_forward;
      case MistakeType.addition:
        return Icons.add_circle_outline;
      case MistakeType.other:
        return Icons.help_outline;
      default:
        return Icons.help_outline;
    }
  }
}
