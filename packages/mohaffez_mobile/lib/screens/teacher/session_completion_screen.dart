// screens/session_completion_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme_constants.dart';
import '../../providers/quiz_access_provider.dart';
import 'package:mohaffez_core/src/providers/session_provider_paginated.dart';
import 'package:mohaffez_core/src/utils/error_handler.dart';
import 'package:mohaffez_core/src/models/quran_mistake_model.dart';
import '../../shared/widgets/interactive_quran_page.dart';
import 'package:mohaffez_core/src/utils/arabic_labels.dart';

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
  // Ayah range for new hifz
  final newHifzFromAyahController = TextEditingController();
  final newHifzToAyahController = TextEditingController();
  // Ayah range for new muraja
  final newMurajaFromAyahController = TextEditingController();
  final newMurajaToAyahController = TextEditingController();

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
    newHifzFromAyahController.dispose();
    newHifzToAyahController.dispose();
    newMurajaFromAyahController.dispose();
    newMurajaToAyahController.dispose();
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
            // Ayah range for new hifz
            newHifzFromAyah: newHifzFromAyahController.text.trim().isEmpty
                ? null
                : newHifzFromAyahController.text.trim(),
            newHifzToAyah: newHifzToAyahController.text.trim().isEmpty
                ? null
                : newHifzToAyahController.text.trim(),
            // Ayah range for new muraja
            newMurajaFromAyah: newMurajaFromAyahController.text.trim().isEmpty
                ? null
                : newMurajaFromAyahController.text.trim(),
            newMurajaToAyah: newMurajaToAyahController.text.trim().isEmpty
                ? null
                : newMurajaToAyahController.text.trim(),
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
      context.pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isLateCompletion
                ? 'تم إكمال الجلسة المتأخرة بنجاح ✓'
                : 'تم إكمال الجلسة بنجاح ✓',
          ),
          backgroundColor:
              widget.isLateCompletion ? AppThemeConstants.warning : AppThemeConstants.secondary,
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
            backgroundColor: AppThemeConstants.secondary,
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
              widget.isLateCompletion ? AppThemeConstants.warning : AppThemeConstants.secondary,
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
                    color: AppThemeConstants.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppThemeConstants.primary.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppThemeConstants.primary, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'هذه جلسة متأخرة - يُفضل إكمال الجلسات في موعدها',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppThemeConstants.primary,
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
                          color: AppThemeConstants.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppThemeConstants.secondary,
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
                                color: AppThemeConstants.grey500,
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
                  color: AppThemeConstants.accentBlue,
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
                              color: AppThemeConstants.successLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppThemeConstants.accentGreenAlt),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.menu_book,
                                        size: 18, color: AppThemeConstants.success),
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
                            activeColor: AppThemeConstants.secondary,
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
                            color: AppThemeConstants.success,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Previous Muraja
                        if (widget.previousMuraja != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppThemeConstants.primary.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.history_edu,
                                        size: 18, color: AppThemeConstants.accentBlue),
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
                            activeColor: AppThemeConstants.secondary,
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
                            color: AppThemeConstants.accentBlue,
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
                color: AppThemeConstants.secondary,
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
                              backgroundColor: AppThemeConstants.primary,
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
                              ? AppThemeConstants.successLight
                              : AppThemeConstants.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sessionMistakes.isEmpty
                                ? AppThemeConstants.accentGreenAlt
                                : AppThemeConstants.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              sessionMistakes.isEmpty
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: sessionMistakes.isEmpty
                                  ? AppThemeConstants.success
                                  : AppThemeConstants.warning,
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
                                color: AppThemeConstants.white,
                              ),
                            ),
                            title: Text(
                                'صفحة ${m.pageNumber} - آية ${m.ayahNumber}'),
                            subtitle:
                                m.wordText != null ? Text(m.wordText!) : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: AppThemeConstants.error),
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

              // Section 3: Quiz unlock toggle
              _buildSectionHeader(
                icon: Icons.extension_rounded,
                title: 'تحديات الجلسة',
                color: AppThemeConstants.primary,
              ),
              const SizedBox(height: 12),
              _QuizToggleCard(sessionId: widget.sessionId),

              const SizedBox(height: 24),

              // Section 4: New assignments
              _buildSectionHeader(
                icon: Icons.assignment,
                title: 'التكليف الجديد للجلسة القادمة',
                color: AppThemeConstants.primary,
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
                          hintText: 'مثال: سورة الكهف',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(
                            Icons.menu_book,
                            color: AppThemeConstants.success,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Hifz ayah range
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: newHifzFromAyahController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'من آية رقم',
                                hintText: 'مثال: 1',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(
                                  Icons.format_list_numbered,
                                  color: AppThemeConstants.success,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward, color: AppThemeConstants.grey400),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: newHifzToAyahController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'إلى آية رقم',
                                hintText: 'مثال: 10',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(
                                  Icons.format_list_numbered,
                                  color: AppThemeConstants.success,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // New muraja
                      TextFormField(
                        controller: newMurajaController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'المراجعة المطلوبة',
                          hintText: 'مثال: سورة البقرة',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(
                            Icons.history_edu,
                            color: AppThemeConstants.accentBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Muraja ayah range
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: newMurajaFromAyahController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'من آية رقم',
                                hintText: 'مثال: 1',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(
                                  Icons.format_list_numbered,
                                  color: AppThemeConstants.accentBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward, color: AppThemeConstants.grey400),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: newMurajaToAyahController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'إلى آية رقم',
                                hintText: 'مثال: 50',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(
                                  Icons.format_list_numbered,
                                  color: AppThemeConstants.accentBlue,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                color: AppThemeConstants.accentAmber,
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
                        color: AppThemeConstants.accentAmber,
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
                            color: AppThemeConstants.white,
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
                        ? AppThemeConstants.warning
                        : AppThemeConstants.secondary,
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
                color: AppThemeConstants.grey500,
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
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ضعيف',
              style: TextStyle(fontSize: 12, color: AppThemeConstants.grey600),
            ),
            Text(
              'ممتاز',
              style: TextStyle(fontSize: 12, color: AppThemeConstants.grey600),
            ),
          ],
        ),
      ],
    );
  }

  Color _mistakeColor(MistakeType type) {
    switch (type) {
      case MistakeType.tajweed:
        return AppThemeConstants.warning;
      case MistakeType.pronunciation:
        return AppThemeConstants.error;
      case MistakeType.reading:
        return AppThemeConstants.accentPurple;
      case MistakeType.skip:
        return AppThemeConstants.accentBlue;
      case MistakeType.addition:
        return AppThemeConstants.success;
      case MistakeType.other:
        return AppThemeConstants.grey500;
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

class _QuizToggleCard extends ConsumerWidget {
  final String sessionId;
  const _QuizToggleCard({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizAsync = ref.watch(sessionQuizStateProvider(sessionId));
    final isUnlocked = quizAsync.valueOrNull ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? AppThemeConstants.secondary.withValues(alpha: 0.12)
                    : AppThemeConstants.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isUnlocked ? Icons.extension_rounded : Icons.lock_rounded,
                color: isUnlocked
                    ? AppThemeConstants.secondary
                    : AppThemeConstants.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUnlocked ? 'التحديات مفعّلة للطالب' : 'التحديات مغلقة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isUnlocked
                          ? AppThemeConstants.secondary
                          : AppThemeConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isUnlocked
                        ? 'يمكن للطالب الآن فتح تحديات الجلسة'
                        : 'فعّل الزر ليتمكن الطالب من دخول التحديات',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppThemeConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isUnlocked,
              activeThumbColor: AppThemeConstants.secondary,
              activeTrackColor:
                  AppThemeConstants.secondary.withValues(alpha: 0.4),
              onChanged: (val) async {
                try {
                  await setQuizUnlocked(sessionId: sessionId, unlocked: val);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تعذّر تغيير حالة التحديات'),
                        backgroundColor: AppThemeConstants.error,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}



