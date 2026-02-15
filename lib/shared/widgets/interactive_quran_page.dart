// lib/shared/widgets/interactive_quran_page.dart

import 'package:flutter/material.dart';
import '../../models/quran_mistake_model.dart';
import '../../services/quran_service.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ Add this

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

    setState(() {
      currentPage = newPage;
    });

    widget.onPageChanged?.call(newPage);
    _loadPageData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Mistake type selector (for teacher)
        if (widget.isEditable) _buildMistakeTypeSelector(),

        // Quran page with tap detection
        Expanded(
          child: GestureDetector(
            onTapDown: widget.isEditable ? _handleTapDown : null,
            child: Stack(
              children: [
                // Quran page image
                _buildQuranPageImage(),

                // Overlay existing mistakes
                ..._buildMistakeMarkers(),
              ],
            ),
          ),
        ),

        // Page navigation
        _buildPageNavigation(),
      ],
    );
  }

  Widget _buildQuranPageImage() {
    return Container(
      color: const Color(0xFFF5F3E8),
      child: Center(
        child: CachedNetworkImage( // ✅ Changed from Image.asset
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
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'الجزء ${pageInfo?['juz'] ?? ''}',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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
  void _handleTapDown(TapDownDetails details) {
    // Get relative position (0.0 to 1.0)
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(details.globalPosition);
    final size = box.size;

    final xPosition = localPosition.dx / size.width;
    final yPosition = localPosition.dy / size.height;

    // Show mistake details dialog
    _showMistakeDialog(xPosition, yPosition);
  }

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
    MistakeType dialogMistakeType = selectedMistakeType; // ✅ Local state for dialog

    final result = await showDialog<QuranMistake>(
      context: context,
      builder: (ctx) => StatefulBuilder( // ✅ Use StatefulBuilder for dialog state
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تحديد الخطأ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ayah selector
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'رقم الآية'),
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
                          final verse = verses.firstWhere((v) => v['verse'] == val);
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
                    decoration: const InputDecoration(labelText: 'نوع الخطأ'),
                    value: dialogMistakeType,
                    items: MistakeType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getMistakeTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          dialogMistakeType = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Correction note
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة التصحيح',
                      hintText: 'اشرح الخطأ وكيفية التصحيح...',
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
                    id: DateTime.now().millisecondsSinceEpoch.toString(), // ✅ ADD THIS
                    pageNumber: currentPage,
                    surahNumber: selectedSurah, // ✅ ADD THIS
                    ayahNumber: selectedAyah,
                    type: dialogMistakeType, // ✅ Use dialog state
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

  List<Widget> _buildMistakeMarkers() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return widget.existingMistakes
        .where((m) => m.pageNumber == currentPage)
        .map((mistake) {
      return Positioned(
        left: (mistake.xPosition ?? 0) * screenWidth,
        top: (mistake.yPosition ?? 0) * screenHeight,
        child: GestureDetector(
          onTap: () => _showMistakeDetails(mistake),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _getMistakeColor(mistake.type).withOpacity(0.8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
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
      );
    }).toList();
  }

  void _showMistakeDetails(QuranMistake mistake) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(_getMistakeIcon(mistake.type), 
                   color: _getMistakeColor(mistake.type)),
              const SizedBox(width: 8),
              Expanded(child: Text(_getMistakeTypeLabel(mistake.type))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الصفحة: ${mistake.pageNumber}'),
              Text('الآية: ${mistake.ayahNumber}'),
              if (mistake.wordText != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'الكلمة:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  mistake.wordText!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (mistake.correctionNote != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'ملاحظة التصحيح:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(mistake.correctionNote!),
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPageNavigation() {
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
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: currentPage > 1 ? () => _changePage(currentPage - 1) : null,
            tooltip: 'الصفحة السابقة',
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'صفحة $currentPage',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (pageInfo != null)
                Text(
                  'الجزء ${pageInfo!['juz']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
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

  // Helper methods
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
