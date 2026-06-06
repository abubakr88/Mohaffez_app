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

class _RateSessionScreenState extends ConsumerState<RateSessionScreen> {
  int rating = 0; // Default to 0 to require explicit user selection
  final notesController = TextEditingController();
  bool _isSubmitting = false;
  _Punctuality? _punctuality;

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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppThemeConstants.error),
              child: const Text('تأكيد الغياب', style: TextStyle(color: AppThemeConstants.white)),
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
    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار تقييم من 1 إلى 10'),
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
    if (r <= 2) return 'ضعيف جداً';
    if (r <= 4) return 'ضعيف';
    if (r <= 6) return 'مقبول';
    if (r <= 8) return 'جيد';
    if (r == 9) return 'جيد جداً';
    return 'ممتاز';
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
          title: const Text('تقييم المحفظ'),
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
                            style: TextStyle(fontSize: 12, color: AppThemeConstants.textSecondary),
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

              // Rating Section
              const Text(
                'تقييمك للجلسة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ضعيف', style: TextStyle(fontSize: 12, color: AppThemeConstants.error)),
                  Text('ممتاز', style: TextStyle(fontSize: 12, color: AppThemeConstants.success)),
                ],
              ),
              const SizedBox(height: 16),

              // Star Rating (10 stars) — size 28 + spacing 4 = ~320px fits in one row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(10, (index) {
                  final starRating = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => rating = starRating),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedScale(
                        scale: index < rating ? 1.25 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.elasticOut,
                        child: Icon(
                          index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: index < rating
                              ? AppThemeConstants.secondary
                              : AppThemeConstants.textSecondary.withValues(alpha: 0.4),
                          size: 30,
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppThemeConstants.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$rating / 10',
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
                    onTap: () => setState(() => _punctuality = _Punctuality.onTime),
                  ),
                  _PunctualityChip(
                    label: 'تأخر بسيط (أقل من 10 دقائق)',
                    icon: Icons.schedule,
                    selected: _punctuality == _Punctuality.slightlyLate,
                    color: AppThemeConstants.warning,
                    onTap: () =>
                        setState(() => _punctuality = _Punctuality.slightlyLate),
                  ),
                  _PunctualityChip(
                    label: 'متأخر أكثر من 10 دقائق',
                    icon: Icons.error_outline,
                    selected: _punctuality == _Punctuality.late,
                    color: AppThemeConstants.error,
                    onTap: () => setState(() => _punctuality = _Punctuality.late),
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
                  hintText: 'شاركنا رأيك حول الجلسة...',
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
                    disabledBackgroundColor: AppThemeConstants.primary.withValues(alpha: 0.6),
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
          color: selected ? color.withValues(alpha: 0.12) : AppThemeConstants.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppThemeConstants.grey300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? color : AppThemeConstants.grey600),
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
