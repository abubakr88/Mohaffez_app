import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../providers/session_provider_paginated.dart';

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

class _RateSessionScreenState extends ConsumerState<RateSessionScreen> {
  int rating = 0; // Default to 0 to require explicit user selection
  final notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
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
    setState(() => _isSubmitting = true);

    try {
      await ref.read(sessionActionsProvider.notifier).updateAssignment(
            sessionId: widget.sessionId,
            rating: rating,
            notes: notesController.text.trim(),
          );

      if (mounted) {
        context.pop(true);
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
              const Text(
                'اختر تقييمك من 1 إلى 10',
                style: TextStyle(fontSize: 14, color: AppThemeConstants.textSecondary),
              ),
              const SizedBox(height: 24),

              // Star Rating (10 stars)
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(10, (index) {
                    final starRating = index + 1;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          rating = starRating;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedScale(
                        scale: index < rating ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.elasticOut,
                        child: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: AppThemeConstants.secondary,
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),

              // Rating display
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$rating / 10',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.secondary,
                    ),
                  ),
                ),
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
            ],
          ),
        ),
      ),
    );
  }
}
