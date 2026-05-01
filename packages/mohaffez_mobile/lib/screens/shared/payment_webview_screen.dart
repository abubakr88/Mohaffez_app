import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:mohaffez_core/src/models/payment_model.dart';
import 'package:mohaffez_core/src/models/pricing_plan_model.dart';
import 'package:mohaffez_core/src/providers/payment_provider.dart';
import '../../shared/theme/app_theme_constants.dart';

class PaymentWebViewScreen extends ConsumerStatefulWidget {
  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.paymentId,
    required this.plan,
  });

  final String paymentUrl;
  final String paymentId;
  final PricingPlanModel plan;

  @override
  ConsumerState<PaymentWebViewScreen> createState() =>
      _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends ConsumerState<PaymentWebViewScreen> {
  late final WebViewController controller;
  int loadingProgress = 0;
  bool paymentCompleted = false;
  Timer? _timeoutTimer;
  ProviderSubscription<AsyncValue<PaymentModel?>>? _paymentStatusSub;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _timeoutTimer = Timer(const Duration(minutes: 3), () {
      if (!paymentCompleted && mounted) {
        _showTimeoutDialog();
      }
    });
    _listenToPaymentStatus();
  }

  void _initWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() => loadingProgress = progress);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => loadingProgress = 0);
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => loadingProgress = 100);
            if (_isSuccessUrl(url)) {
              _showSuccessAnimation();
            }
          },
          onNavigationRequest: (request) {
            if (_isSuccessUrl(request.url)) {
              _showSuccessAnimation();
            }
            if (_isFailureUrl(request.url)) {
              _showFailureDialog('فشلت عملية الدفع');
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            _showFailureDialog(error.description);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _listenToPaymentStatus() {
    _paymentStatusSub = ref.listenManual<AsyncValue<PaymentModel?>>(
      paymentStatusProvider(widget.paymentId),
      (_, next) {
        final payment = next.valueOrNull;
        if (payment == null) return;
        if (payment.status == PaymentStatus.completed) {
          _showSuccessAnimation();
        } else if (payment.status == PaymentStatus.failed) {
          _showFailureDialog(payment.failureReason ?? 'فشلت عملية الدفع');
        }
      },
      fireImmediately: true,
    );
  }

  bool _isSuccessUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('success') || lower.contains('completed');
  }

  bool _isFailureUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('fail') || lower.contains('error');
  }

  String getPaymentStage(int progress) {
    if (progress < 30) return 'الاتصال ببوابة الدفع...';
    if (progress < 60) return 'في انتظار تأكيد البنك...';
    if (progress < 85) return 'معالجة الدفع...';
    return 'جاري التأكيد النهائي...';
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.access_time, color: AppThemeConstants.warning),
            SizedBox(width: 8),
            Text('انتهى الوقت'),
          ],
        ),
        content: const Text(
          'استغرق الدفع وقتاً طويلاً. يرجى المحاولة مرة أخرى.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, false);
            },
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSuccessAnimation() {
    if (paymentCompleted || !mounted) return;
    setState(() => paymentCompleted = true);
    _timeoutTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: const Icon(Icons.check_circle,
                  color: AppThemeConstants.success, size: 100),
            ),
            const SizedBox(height: 16),
            const Text(
              'تم الدفع بنجاح!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppThemeConstants.success,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'سيتم تأكيد حجزك خلال ثوانٍ',
              style: TextStyle(fontSize: 14, color: AppThemeConstants.textSecondary),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      // FIXED: guard with both mounted (StatefulWidget) and context.mounted (BuildContext)
      if (!mounted || !context.mounted) return;
      try {
        Navigator.popUntil(context, (route) => route.isFirst);
      } catch (e) {
        // Navigator may already be in a different state if user navigated away
        // during the 2-second delay. Absorb silently — payment already succeeded.
        debugPrint('PaymentWebViewScreen: popUntil on stale context: $e');
      }
    });
  }

  void _showFailureDialog(String reason) {
    if (!mounted) return;
    _timeoutTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('فشل الدفع'),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop(false);
            },
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => loadingProgress = 0);
              controller.reload();
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _paymentStatusSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          title: const Text('إتمام الدفع'),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (loadingProgress < 100)
              Container(
                color: AppThemeConstants.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: loadingProgress / 100,
                          strokeWidth: 6,
                          backgroundColor: AppThemeConstants.grey200,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(AppThemeConstants.success),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        getPaymentStage(loadingProgress),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$loadingProgress%',
                        style:
                            const TextStyle(fontSize: 14, color: AppThemeConstants.grey500),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: loadingProgress / 100,
                          minHeight: 8,
                          backgroundColor: AppThemeConstants.grey200,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(AppThemeConstants.success),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'لا تغلق هذه الصفحة حتى اكتمال العملية',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppThemeConstants.grey600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
