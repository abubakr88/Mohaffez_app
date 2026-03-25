// lib/screens/exam_result_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/system_config_model.dart';
import '../models/user_model.dart';
import '../providers/system_config_provider.dart';
import '../providers/user_provider.dart';
import '../services/cache_service.dart';

class ExamResultScreen extends ConsumerWidget {
  final double score;
  final int correctAnswers;
  final int totalQuestions;

  const ExamResultScreen({
    super.key,
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(systemConfigProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('حدث خطأ: $e')),
          data: (config) => userAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('حدث خطأ: $e')),
            data: (user) => _buildResultContent(context, ref, config, user),
          ),
        ),
      ),
    );
  }

  Widget _buildResultContent(
    BuildContext context,
    WidgetRef ref,
    SystemConfigModel config,
    UserModel? user,
  ) {
    final bool passed = score >= config.examPassingScore;
    final int retryCount = user?.examRetryCount ?? 0;
    final bool canRetry = retryCount < config.examMaxRetries;
    final DateTime? nextRetryAt = user?.examNextRetryAt;
    final bool isRetryCooldownActive =
        nextRetryAt != null && DateTime.now().isBefore(nextRetryAt);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: passed
              ? [Colors.green.shade50, Colors.white]
              : [Colors.orange.shade50, Colors.white],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              // Status Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: passed ? Colors.green.shade100 : Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  passed ? Icons.check_circle : Icons.warning_rounded,
                  size: 64,
                  color: passed ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 24),

              // Result Message
              Text(
                passed ? 'تهانينا!' : 'لم تنجح في الاختبار',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: passed ? Colors.green : Colors.orange.shade800,
                    ),
              ),
              const SizedBox(height: 16),

              // Score Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '${score.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: passed ? Colors.green : Colors.orange,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$correctAnswers / $totalQuestions إجابات صحيحة',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الحد الأدنى للنجاح: ${config.examPassingScore.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Pass Message
              if (passed) ...[
                Text(
                  'لقد اجتزت اختبار المحفظ بنجاح!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'يمكنك الآن البدء في استقبال طلبات التحفيظ.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => context.go('/mohaffez-home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'الانتقال للصفحة الرئيسية',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],

              // Fail Message
              if (!passed) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'معلومات مهمة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        canRetry
                            ? 'يمكنك إعادة الاختبار بعد ${config.examRetryCooldownDays} أيام من الآن.'
                            : 'لقد استنفدت جميع محاولات إعادة الاختبار (${config.examMaxRetries} محاولات).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                      if (canRetry && retryCount > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'محاولاتك السابقة: $retryCount / ${config.examMaxRetries}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (isRetryCooldownActive) ...[
                        const SizedBox(height: 12),
                        _RetryCountdown(nextRetryAt: nextRetryAt),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                if (canRetry) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isRetryCooldownActive
                          ? null
                          : () => _retryExam(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isRetryCooldownActive
                            ? 'انتظر انتهاء العداد'
                            : 'إعادة الاختبار',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _logout(context, ref),
                    child: const Text('تسجيل الخروج'),
                  ),
                ] else ...[
                  // No more retries
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _logout(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'إذا كنت تعتقد أن هناك خطأ، يرجى التواصل مع الدعم.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }

  void _retryExam(BuildContext context, WidgetRef ref) {
    // Clear setup cache and restart
    CacheService.clearAll();
    context.go('/setup');
  }

  void _logout(BuildContext context, WidgetRef ref) {
    // Navigate to login
    context.go('/login');
  }
}

class _RetryCountdown extends StatefulWidget {
  final DateTime nextRetryAt;

  const _RetryCountdown({required this.nextRetryAt});

  @override
  State<_RetryCountdown> createState() => _RetryCountdownState();
}

class _RetryCountdownState extends State<_RetryCountdown> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startTimer();
  }

  void _updateRemaining() {
    final now = DateTime.now();
    if (widget.nextRetryAt.isAfter(now)) {
      _remaining = widget.nextRetryAt.difference(now);
    } else {
      _remaining = Duration.zero;
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _updateRemaining());
      return _remaining > Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            days > 0
                ? '$days يوم ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
                : '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
