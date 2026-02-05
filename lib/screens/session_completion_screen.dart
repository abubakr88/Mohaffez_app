// screens/session_completion_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/constants/app_theme.dart';
import '../providers/session_provider_paginated.dart';
import '../shared/utils/error_handler.dart';

class SessionCompletionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String studentName;
  final String? previousHifz;
  final String? previousMuraja;
  final bool isLateCompletion; // ✅ NEW PARAMETER

  const SessionCompletionScreen({
    super.key,
    required this.sessionId,
    required this.studentName,
    this.previousHifz,
    this.previousMuraja,
    this.isLateCompletion = false, // ✅ DEFAULT FALSE
  });

  @override
  ConsumerState<SessionCompletionScreen> createState() =>
      _SessionCompletionScreenState();
}

class _SessionCompletionScreenState
    extends ConsumerState<SessionCompletionScreen> {
  final _formKey = GlobalKey<FormState>();

  // التكليف السابق
  bool previousHifzCompleted = false;
  int previousHifzRating = 5;
  bool previousMurajaCompleted = false;
  int previousMurajaRating = 5;
  final performanceNotesController = TextEditingController();

  // التكليف الجديد
  final newHifzController = TextEditingController();
  final newMurajaController = TextEditingController();

  // التقييم العام
  int sessionRating = 7;
  final generalNotesController = TextEditingController();

  bool isSubmitting = false;

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
      await ref.read(sessionActionsProvider.notifier).completeSessionWithDetails(
            sessionId: widget.sessionId,
            // تقييم التكليف السابق
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
            // التكليف الجديد
            newHifzAssignment: newHifzController.text.trim().isEmpty
                ? null
                : newHifzController.text.trim(),
            newMurajaAssignment: newMurajaController.text.trim().isEmpty
                ? null
                : newMurajaController.text.trim(),
            // التقييم العام
            sessionRating: sessionRating,
            generalNotes: generalNotesController.text.trim().isEmpty
                ? null
                : generalNotesController.text.trim(),
            // ✅ NEW: Flag for late completion
            isLateCompletion: widget.isLateCompletion,
          );

      if (!mounted) return;

      // رجوع مع رسالة نجاح
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isLateCompletion
                ? 'تم إكمال الجلسة المتأخرة بنجاح ✓'
                : 'تم إكمال الجلسة بنجاح ✓',
          ),
          backgroundColor: widget.isLateCompletion ? Colors.orange : AppTheme.accentGreen,
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

  @override
  Widget build(BuildContext context) {
    final hasPreviousAssignment =
        widget.previousHifz != null || widget.previousMuraja != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isLateCompletion ? 'إكمال جلسة متأخرة' : 'إكمال الجلسة',
          ),
          backgroundColor: widget.isLateCompletion ? Colors.orange : AppTheme.accentGreen,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ✅ Late Warning Banner
              if (widget.isLateCompletion)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade700, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'هذه جلسة متأخرة - يُفضل إكمال الجلسات في موعدها',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // معلومات الطالب
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withOpacity(0.1),
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

              // ✅ القسم الأول: مراجعة التكليف السابق
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
                        // الحفظ السابق
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
                                    Text(
                                      'الحفظ المطلوب كان:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
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
                            onChanged: (val) =>
                                setState(() => previousHifzRating = val.toInt()),
                            color: Colors.green,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // المراجعة السابقة
                        if (widget.previousMuraja != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.history_edu,
                                        size: 18, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text(
                                      'المراجعة المطلوبة كانت:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
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

                        // ملاحظات الأداء
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

              // ✅ القسم الثاني: إسناد التكليف الجديد
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
                      // حفظ جديد
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

                      // مراجعة جديدة
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

              // ✅ القسم الثالث: التقييم العام للجلسة
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

                      // ملاحظات عامة
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

              // زر الحفظ
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
                    isSubmitting ? 'جاري الحفظ...' : 'إكمال الجلسة وحفظ التقييم',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isLateCompletion ? Colors.orange : AppTheme.accentGreen,
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
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
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
            inactiveTrackColor: color.withOpacity(0.3),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
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
}
