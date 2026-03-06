// screens/session_completion_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/constants/app_theme.dart';
import '../shared/theme/app_theme_constants.dart';
import '../providers/session_provider_paginated.dart';
import '../shared/utils/error_handler.dart';
import '../models/quran_mistake_model.dart';
import '../shared/widgets/interactive_quran_page.dart';
import '../utils/arabic_labels.dart';

class SessionCompletionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String studentName;
  final String? previousHifz;
  final String? previousMuraja;
  final bool isLateCompletion;

  const SessionCompletionScreen({
    super.key,
    required this.sessionId,
    required this.studentName,
    this.previousHifz,
    this.previousMuraja,
    this.isLateCompletion = false,
  });

  @override
  ConsumerState<SessionCompletionScreen> createState() =>
      _SessionCompletionScreenState();
}

class _SessionCompletionScreenState
    extends ConsumerState<SessionCompletionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Previous assignment evaluation
  bool previousHifzCompleted = false;
  int previousHifzRating = 5;
  bool previousMurajaCompleted = false;
  int previousMurajaRating = 5;
  final performanceNotesController = TextEditingController();

  // New assignments
  final newHifzController = TextEditingController();
  final newMurajaController = TextEditingController();

  // General session rating
  int sessionRating = 7;
  final generalNotesController = TextEditingController();

  bool isSubmitting = false;

  // Quran mistake tracking state
  int currentQuranPage = 1;
  final List<QuranMistake> sessionMistakes = [];

  @override
  void dispose() {
    performanceNotesController.dispose();
    newHifzController.dispose();
    newMurajaController.dispose();
    generalNotesController.dispose();
    super.dispose();
  }

  Future<void> _completeSession() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSubmitting = true);

    try {
      await ref
          .read(sessionActionsProvider.notifier)
          .completeSessionWithDetails(
            sessionId: widget.sessionId,
            // Previous assignment evaluation
            previousHifzCompleted:
                widget.previousHifz != null ? previousHifzCompleted : null,
            previousHifzRating:
                widget.previousHifz != null ? previousHifzRating : null,
            previousMurajaCompleted:
                widget.previousMuraja != null ? previousMurajaCompleted : null,
            previousMurajaRating:
                widget.previousMuraja != null ? previousMurajaRating : null,
            performanceNotes: performanceNotesController.text.trim().isEmpty
                ? null
                : performanceNotesController.text.trim(),
            // New assignments
            newHifzAssignment: newHifzController.text.trim().isEmpty
                ? null
                : newHifzController.text.trim(),
            newMurajaAssignment: newMurajaController.text.trim().isEmpty
                ? null
                : newMurajaController.text.trim(),
            // General rating
            sessionRating: sessionRating,
            generalNotes: generalNotesController.text.trim().isEmpty
                ? null
                : generalNotesController.text.trim(),
            // Late completion flag
            isLateCompletion: widget.isLateCompletion,
            // Quran mistakes payload
            mistakes: sessionMistakes,
            pagesRead:
                sessionMistakes.map((m) => m.pageNumber).toSet().toList(),
            currentPage: currentQuranPage,
          );

      if (!mounted) return;

      // Return with success message
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isLateCompletion
                ? 'تم إكمال الجلسة المتأخرة بنجاح ✓'
                : 'تم إكمال الجلسة بنجاح ✓',
          ),
          backgroundColor:
              widget.isLateCompletion ? Colors.orange : AppTheme.accentGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  void _openQuranMarking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: context.canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () => context.pop(),
                    tooltip: 'رجوع',
                  )
                : null,
            title: const Text('تحديد الأخطاء على المصحف'),
            backgroundColor: AppTheme.accentGreen,
          ),
          body: InteractiveQuranPage(
            pageNumber: currentQuranPage,
            existingMistakes: sessionMistakes
                .where((m) => m.pageNumber == currentQuranPage)
                .toList(),
            onMistakeAdded: (mistake) {
              setState(() {
                sessionMistakes.add(mistake);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تسجيل الخطأ')),
              );
            },
            onPageChanged: (page) {
              setState(() {
                currentQuranPage = page;
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPreviousAssignment =
        widget.previousHifz != null || widget.previousMuraja != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: Text(
            widget.isLateCompletion ? 'إكمال جلسة متأخرة' : 'إكمال الجلسة',
          ),
          backgroundColor:
              widget.isLateCompletion ? Colors.orange : AppTheme.accentGreen,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Late Warning Banner
              if (widget.isLateCompletion)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.primaryAmber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppThemeConstants.primaryAmber.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppThemeConstants.primaryAmber, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'هذه جلسة متأخرة - يُفضل إكمال الجلسات في موعدها',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppThemeConstants.primaryAmber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Student info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppTheme.accentGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إكمال جلسة',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.studentName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Section 1: Previous assignment review
              if (hasPreviousAssignment) ...[
                _buildSectionHeader(
                  icon: Icons.assignment_turned_in,
                  title: 'مراجعة التكليف السابق',
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Previous Hifz
                        if (widget.previousHifz != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.menu_book,
                                        size: 18, color: Colors.green),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                      'الحفظ المطلوب كان:',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.previousHifz!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: previousHifzCompleted,
                            onChanged: (val) =>
                                setState(() => previousHifzCompleted = val!),
                            title: const Text('أتم الحفظ المطلوب'),
                            activeColor: AppTheme.accentGreen,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'تقييم أداء الحفظ:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildRatingSlider(
                            value: previousHifzRating,
                            onChanged: (val) => setState(
                                () => previousHifzRating = val.toInt()),
                            color: Colors.green,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Previous Muraja
                        if (widget.previousMuraja != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.surfaceWhite,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppThemeConstants.primaryAmber.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.history_edu,
                                        size: 18, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                      'المراجعة المطلوبة كانت:',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.previousMuraja!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: previousMurajaCompleted,
                            onChanged: (val) =>
                                setState(() => previousMurajaCompleted = val!),
                            title: const Text('أتم المراجعة المطلوبة'),
                            activeColor: AppTheme.accentGreen,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'تقييم أداء المراجعة:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildRatingSlider(
                            value: previousMurajaRating,
                            onChanged: (val) => setState(
                                () => previousMurajaRating = val.toInt()),
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Performance notes
                        TextFormField(
                          controller: performanceNotesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'ملاحظات على الأداء في التكليف السابق',
                            hintText:
                                'مثال: أداء ممتاز في الحفظ، يحتاج تحسين التجويد...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.note),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Section 2: Quran mistake tracking
              _buildSectionHeader(
                icon: Icons.menu_book,
                title: 'تسجيل الأخطاء على المصحف',
                color: AppTheme.accentGreen,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _openQuranMarking,
                            icon: const Icon(Icons.book),
                            label: const Text('فتح المصحف'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryAmber,
                            ),
                          ),
                          Text(
                            'صفحة حالية: $currentQuranPage',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sessionMistakes.isEmpty
                              ? Colors.green.shade50
                              : AppThemeConstants.primaryAmber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sessionMistakes.isEmpty
                                ? Colors.green.shade200
                                : AppThemeConstants.primaryAmber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              sessionMistakes.isEmpty
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: sessionMistakes.isEmpty
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              sessionMistakes.isEmpty
                                  ? 'لم يتم تسجيل أخطاء بعد'
                                  : 'تم تسجيل ${sessionMistakes.length} خطأ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (sessionMistakes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...sessionMistakes.map((m) {
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: _mistakeColor(m.type),
                              radius: 16,
                              child: Icon(
                                _mistakeIcon(m.type),
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                                'صفحة ${m.pageNumber} - آية ${m.ayahNumber}'),
                            subtitle:
                                m.wordText != null ? Text(m.wordText!) : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  sessionMistakes.remove(m);
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Section 3: New assignments
              _buildSectionHeader(
                icon: Icons.assignment,
                title: 'التكليف الجديد للجلسة القادمة',
                color: AppTheme.primaryAmber,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // New hifz
                      TextFormField(
                        controller: newHifzController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'الحفظ المطلوب',
                          hintText: 'مثال: سورة الكهف من آية 1 إلى 10',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(
                            Icons.menu_book,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // New muraja
                      TextFormField(
                        controller: newMurajaController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'المراجعة المطلوبة',
                          hintText: 'مثال: سورة البقرة الربع الأول',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(
                            Icons.history_edu,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Section 4: General session rating
              _buildSectionHeader(
                icon: Icons.star,
                title: 'تقييم الجلسة الحالية',
                color: Colors.amber,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'التقييم العام للجلسة:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildRatingSlider(
                        value: sessionRating,
                        onChanged: (val) =>
                            setState(() => sessionRating = val.toInt()),
                        color: Colors.amber,
                        showStars: true,
                      ),
                      const SizedBox(height: 20),
                      // General notes
                      TextFormField(
                        controller: generalNotesController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات عامة للطالب',
                          hintText:
                              'مثال: جلسة مثمرة، الطالب متفاعل، يُنصح بالمواظبة...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.notes),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : _completeSession,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    isSubmitting
                        ? ArabicLabels.loading
                        : 'إكمال الجلسة وحفظ التقييم',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isLateCompletion
                        ? Colors.orange
                        : AppTheme.accentGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSlider({
    required int value,
    required ValueChanged<double> onChanged,
    required Color color,
    bool showStars = false,
  }) {
    return Column(
      children: [
        if (showStars)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(10, (index) {
              return Icon(
                index < value ? Icons.star : Icons.star_border,
                color: color,
                size: 28,
              );
            }),
          ),
        Row(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Text(
              ' / 10',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.3),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
            valueIndicatorColor: color,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: value.toString(),
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ضعيف',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              'ممتاز',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Color _mistakeColor(MistakeType type) {
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
    }
  }

  IconData _mistakeIcon(MistakeType type) {
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
    }
  }
}


