import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../tour/tour_guard_helper.dart';

class RateSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String mohaffezName;

  const RateSessionScreen({
    super.key,
    required this.sessionId,
    required this.mohaffezName,
  });

  @override
  ConsumerState<RateSessionScreen> createState() => _RateSessionScreenState();
}

/// Punctuality answer maps directly to the `startedLate` boolean on the
/// session doc. Only [late] flips the flag to true; the other two leave it
/// as on-time so the session counts toward the teacher's tier.
enum _Punctuality { onTime, slightlyLate, late }

enum _TechnicalIssueSource { none, student, teacher, app, unknown }

enum _LowRatingReason {
  unclearExplanation,
  weakInteraction,
  unprepared,
  inappropriateBehavior,
  technicalOnly,
  other,
}

class _RateSessionScreenState extends ConsumerState<RateSessionScreen> {
  int rating = 0; // Default to 0 to require explicit user selection
  final notesController = TextEditingController();
  bool _isSubmitting = false;
  _Punctuality? _punctuality;
  _TechnicalIssueSource? _technicalIssueSource;
  _LowRatingReason? _lowRatingReason;

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> _reportTeacherNoShow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(children: [
            Icon(Icons.person_off, color: AppThemeConstants.error),
            SizedBox(width: 8),
            Text('المحفظ لم يحضر'),
          ]),
          content: const Text(
            'هل أنت متأكد أن المحفظ لم يحضر الجلسة؟ سيتم استرداد مبلغ الجلسة كاملاً إلى محفظتك وتسجيل تحذير على حساب المحفظ.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('تراجع')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.error),
              child: const Text('تأكيد الغياب',
                  style: TextStyle(color: AppThemeConstants.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('onTeacherNoShowReported')
          .call({'sessionId': widget.sessionId});
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر إرسال الإبلاغ. يرجى المحاولة مرة أخرى'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitRating() async {
    if (guardWriteInTour(ref, context)) return;
    if (_isSubmitting) return;
    if (_technicalIssueSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد ما إذا واجهت مشكلة تقنية'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
      return;
    }
    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تقييم أداء المحفظ من 1 إلى 5'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
      return;
    }
    if (rating <= 2 && _lowRatingReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار سبب التقييم المنخفض'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
      return;
    }
    if (_punctuality == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى الإجابة عن سؤال الالتزام بالموعد'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      await ref.read(sessionActionsProvider.notifier).updateAssignment(
            sessionId: widget.sessionId,
            rating: rating,
            notes: notesController.text.trim(),
            startedLate: _punctuality == _Punctuality.late,
            technicalIssueSource: _technicalIssueSource!.storageValue,
            teacherRatingReason: _lowRatingReason?.storageValue,
          );

      if (mounted) {
        context.pop(rating);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر إرسال التقييم، يرجى المحاولة مرة أخرى'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _ratingLabel(int r) {
    return switch (r) {
      1 => 'ضعيف',
      2 => 'مقبول',
      3 => 'جيد',
      4 => 'جيد جداً',
      5 => 'ممتاز',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: const Text('تقييم أداء المحفظ'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mohaffez Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppThemeConstants.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school,
                        color: AppThemeConstants.success, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'المحفظ',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppThemeConstants.textSecondary),
                          ),
                          Text(
                            widget.mohaffezName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppThemeConstants.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppThemeConstants.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppThemeConstants.primary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'قيّم أداء المحفظ فقط. مشكلات الإنترنت أو التطبيق تُسجّل بشكل منفصل ولا تُنسب تلقائياً إلى المحفظ.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppThemeConstants.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'هل واجهت مشكلة تقنية أثناء الجلسة؟',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر المصدر الذي بدا لك، ويمكنك اختيار «لا أعرف».',
                style: TextStyle(
                  fontSize: 13,
                  color: AppThemeConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _TechnicalIssueSource.values.map((source) {
                  return _PunctualityChip(
                    label: source.label,
                    icon: source.icon,
                    selected: _technicalIssueSource == source,
                    color: source.color,
                    onTap: () {
                      setState(() {
                        _technicalIssueSource = source;
                        if (source == _TechnicalIssueSource.none &&
                            _lowRatingReason ==
                                _LowRatingReason.technicalOnly) {
                          _lowRatingReason = null;
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Teacher performance rating
              const Text(
                'كيف كان أداء المحفظ؟',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ضعيف',
                      style: TextStyle(
                          fontSize: 12, color: AppThemeConstants.error)),
                  Text('ممتاز',
                      style: TextStyle(
                          fontSize: 12, color: AppThemeConstants.success)),
                ],
              ),
              const SizedBox(height: 16),

              // Five labelled choices are easier to interpret consistently.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starRating = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() {
                      rating = starRating;
                      if (starRating > 2) _lowRatingReason = null;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedScale(
                        scale: index < rating ? 1.25 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.elasticOut,
                        child: Icon(
                          index < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: index < rating
                              ? AppThemeConstants.secondary
                              : AppThemeConstants.textSecondary
                                  .withValues(alpha: 0.4),
                          size: 42,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Rating display with label
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(rating),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            AppThemeConstants.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$rating / 5',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppThemeConstants.secondary,
                          ),
                        ),
                        if (rating > 0) ...[
                          const SizedBox(width: 10),
                          Text(
                            _ratingLabel(rating),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppThemeConstants.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              if (rating > 0 && rating <= 2) ...[
                const SizedBox(height: 28),
                const Text(
                  'ما السبب الرئيسي للتقييم المنخفض؟',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يساعد السبب في حماية العدالة وتحسين الخدمة.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppThemeConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _LowRatingReason.values
                      .where((reason) =>
                          reason != _LowRatingReason.technicalOnly ||
                          (_technicalIssueSource != null &&
                              _technicalIssueSource !=
                                  _TechnicalIssueSource.none))
                      .map((reason) => _PunctualityChip(
                            label: reason.label,
                            icon: reason.icon,
                            selected: _lowRatingReason == reason,
                            color: reason == _LowRatingReason.technicalOnly
                                ? AppThemeConstants.info
                                : AppThemeConstants.warning,
                            onTap: () =>
                                setState(() => _lowRatingReason = reason),
                          ))
                      .toList(),
                ),
                if (_lowRatingReason == _LowRatingReason.technicalOnly) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'سيُحفظ البلاغ للمراجعة، ولن يدخل هذا التقييم في متوسط المحفظ العام.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppThemeConstants.info,
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 32),

              // Punctuality question
              const Text(
                'هل بدأت الحلقة في الوقت المحدد؟',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PunctualityChip(
                    label: 'في الوقت',
                    icon: Icons.check_circle_outline,
                    selected: _punctuality == _Punctuality.onTime,
                    color: AppThemeConstants.success,
                    onTap: () =>
                        setState(() => _punctuality = _Punctuality.onTime),
                  ),
                  _PunctualityChip(
                    label: 'تأخر بسيط (أقل من 10 دقائق)',
                    icon: Icons.schedule,
                    selected: _punctuality == _Punctuality.slightlyLate,
                    color: AppThemeConstants.warning,
                    onTap: () => setState(
                        () => _punctuality = _Punctuality.slightlyLate),
                  ),
                  _PunctualityChip(
                    label: 'متأخر أكثر من 10 دقائق',
                    icon: Icons.error_outline,
                    selected: _punctuality == _Punctuality.late,
                    color: AppThemeConstants.error,
                    onTap: () =>
                        setState(() => _punctuality = _Punctuality.late),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Notes Section
              const Text(
                'ملاحظاتك (اختياري)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 5,
                maxLength: 500,
                textInputAction: TextInputAction.done,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    Text(
                  '$currentLength / $maxLength',
                  style: TextStyle(
                    fontSize: 12,
                    color: currentLength > (maxLength ?? 500) * 0.9
                        ? AppThemeConstants.warning
                        : AppThemeConstants.textSecondary,
                  ),
                ),
                decoration: InputDecoration(
                  hintText:
                      'اكتب ملاحظاتك عن أداء المحفظ أو المشكلة التقنية...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppThemeConstants.surface,
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitRating,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppThemeConstants.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting ? 'جاري الإرسال...' : 'إرسال التقييم',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primary,
                    disabledBackgroundColor:
                        AppThemeConstants.primary.withValues(alpha: 0.6),
                    foregroundColor: AppThemeConstants.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Teacher no-show report
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _reportTeacherNoShow,
                  icon: const Icon(Icons.person_off_outlined, size: 18),
                  label: const Text('المحفظ لم يحضر الجلسة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppThemeConstants.error,
                    side: const BorderSide(color: AppThemeConstants.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PunctualityChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PunctualityChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : AppThemeConstants.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppThemeConstants.grey300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18, color: selected ? color : AppThemeConstants.grey600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : AppThemeConstants.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _TechnicalIssueSource {
  String get storageValue => switch (this) {
        _TechnicalIssueSource.none => 'none',
        _TechnicalIssueSource.student => 'student',
        _TechnicalIssueSource.teacher => 'teacher',
        _TechnicalIssueSource.app => 'app',
        _TechnicalIssueSource.unknown => 'unknown',
      };

  String get label => switch (this) {
        _TechnicalIssueSource.none => 'لم توجد مشكلة',
        _TechnicalIssueSource.student => 'الإنترنت لدي',
        _TechnicalIssueSource.teacher => 'الإنترنت لدى المحفظ',
        _TechnicalIssueSource.app => 'التطبيق أو رابط الاجتماع',
        _TechnicalIssueSource.unknown => 'لا أعرف',
      };

  IconData get icon => switch (this) {
        _TechnicalIssueSource.none => Icons.check_circle_outline,
        _TechnicalIssueSource.student => Icons.wifi_off_outlined,
        _TechnicalIssueSource.teacher => Icons.person_outline,
        _TechnicalIssueSource.app => Icons.mobile_off_outlined,
        _TechnicalIssueSource.unknown => Icons.help_outline,
      };

  Color get color => switch (this) {
        _TechnicalIssueSource.none => AppThemeConstants.success,
        _TechnicalIssueSource.student => AppThemeConstants.warning,
        _TechnicalIssueSource.teacher => AppThemeConstants.warning,
        _TechnicalIssueSource.app => AppThemeConstants.info,
        _TechnicalIssueSource.unknown => AppThemeConstants.textSecondary,
      };
}

extension on _LowRatingReason {
  String get storageValue => switch (this) {
        _LowRatingReason.unclearExplanation => 'unclear_explanation',
        _LowRatingReason.weakInteraction => 'weak_interaction',
        _LowRatingReason.unprepared => 'unprepared',
        _LowRatingReason.inappropriateBehavior => 'inappropriate_behavior',
        _LowRatingReason.technicalOnly => 'technical_only',
        _LowRatingReason.other => 'other',
      };

  String get label => switch (this) {
        _LowRatingReason.unclearExplanation => 'الشرح أو التصحيح غير واضح',
        _LowRatingReason.weakInteraction => 'ضعف التفاعل',
        _LowRatingReason.unprepared => 'عدم الاستعداد',
        _LowRatingReason.inappropriateBehavior => 'سلوك غير مناسب',
        _LowRatingReason.technicalOnly => 'مشكلة تقنية فقط',
        _LowRatingReason.other => 'سبب آخر',
      };

  IconData get icon => switch (this) {
        _LowRatingReason.unclearExplanation => Icons.menu_book_outlined,
        _LowRatingReason.weakInteraction => Icons.forum_outlined,
        _LowRatingReason.unprepared => Icons.event_busy_outlined,
        _LowRatingReason.inappropriateBehavior => Icons.report_outlined,
        _LowRatingReason.technicalOnly => Icons.wifi_off_outlined,
        _LowRatingReason.other => Icons.more_horiz,
      };
}
