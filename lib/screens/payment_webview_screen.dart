// lib/screens/payment_webview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

import '../models/pricing_plan_model.dart';
import '../models/payment_model.dart';
import '../providers/payment_provider.dart';
import '../shared/constants/app_theme.dart';

class PaymentWebViewScreen extends ConsumerStatefulWidget {
  final String paymentUrl;
  final String paymentId;
  final PricingPlanModel plan;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.paymentId,
    required this.plan,
  });

  @override
  ConsumerState<PaymentWebViewScreen> createState() =>
      _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends ConsumerState<PaymentWebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  int loadingProgress = 0;
  Timer? _timeoutTimer;
  StreamSubscription<PaymentModel?>? _paymentStatusSub;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _startTimeout();
    _listenToPaymentStatus();
  }

  void _initializeWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              loadingProgress = progress;
              if (progress == 100) {
                isLoading = false;
              }
            });
          },
          onPageStarted: (String url) {
            setState(() => isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => isLoading = false);
            _checkPaymentStatusFromUrl(url);
          },
          onWebResourceError: (WebResourceError error) {
            _showErrorDialog(error.description);
          },
          onNavigationRequest: (NavigationRequest request) {
            _checkPaymentStatusFromUrl(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  /// Listen to backend payment status updates (real source of truth)
  void _listenToPaymentStatus() {
    _paymentStatusSub = ref
        .read(paymentStatusProvider(widget.paymentId).stream)
        .listen((payment) {
      if (payment == null) return;

      if (payment.status == PaymentStatus.completed) {
        _timeoutTimer?.cancel();
        _handlePaymentSuccess();
      } else if (payment.status == PaymentStatus.failed) {
        _timeoutTimer?.cancel();
        _handlePaymentFailure(
            payment.failureReason ?? 'فشلت عملية الدفع');
      }
    });
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(minutes: 10), () {
      if (mounted) {
        _showTimeoutDialog();
      }
    });
  }

  /// Provisional URL-based check (UX hint only)
  void _checkPaymentStatusFromUrl(String url) {
    if (url.contains('success=true') || url.contains('/payment/success')) {
      // Show interim loading; backend listener will confirm
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري التحقق من حالة الدفع...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else if (url.contains('success=false') || url.contains('/payment/fail')) {
      _timeoutTimer?.cancel();
      _handlePaymentFailure('فشلت عملية الدفع');
    }
  }

  void _handlePaymentSuccess() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentSuccessDialog(
        plan: widget.plan,
        onContinue: () {
          Navigator.pop(ctx);
          Navigator.pop(context, true);
        },
      ),
    );
  }

  void _handlePaymentFailure(String reason) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentFailureDialog(
        reason: reason,
        onRetry: () {
          Navigator.pop(ctx);
          setState(() {
            isLoading = true;
            controller.reload();
          });
        },
        onCancel: () {
          Navigator.pop(ctx);
          Navigator.pop(context, false);
        },
        onContactSupport: () {
          // TODO: Implement support contact
          Navigator.pop(ctx);
          Navigator.pop(context, false);
        },
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('خطأ في التحميل'),
          content: Text(error),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, false);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.reload();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('انتهت المهلة'),
          content: const Text(
            'استغرقت عملية الدفع وقتًا طويلاً. يرجى المحاولة مرة أخرى.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, false);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _startTimeout();
                controller.reload();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _paymentStatusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إتمام الدفع'),
          backgroundColor: AppTheme.accentGreen,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _showCancelConfirmation(),
              tooltip: 'إلغاء',
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (isLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                          AppTheme.accentGreen,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'جاري تحميل صفحة الدفع... $loadingProgress%',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'يرجى عدم إغلاق الصفحة',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.green.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'اتصال آمن ومشفر',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
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

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء الدفع'),
          content: const Text(
            'هل أنت متأكد من إلغاء عملية الدفع؟ سيتم فقدان التقدم الحالي.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('لا، استمر'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('نعم، إلغاء'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Payment Success Dialog
class PaymentSuccessDialog extends StatelessWidget {
  final PricingPlanModel plan;
  final VoidCallback onContinue;

  const PaymentSuccessDialog({
    super.key,
    required this.plan,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: AppTheme.accentGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'تم الدفع بنجاح! 🎉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'تم شراء ${plan.title} بنجاح',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${plan.priceEGP.toStringAsFixed(0)} ج.م',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.accentGreen,
                ),
                child: const Text(
                  'متابعة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Payment Failure Dialog
class PaymentFailureDialog extends StatelessWidget {
  final String reason;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onContactSupport;

  const PaymentFailureDialog({
    super.key,
    required this.reason,
    required this.onRetry,
    required this.onCancel,
    required this.onContactSupport,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'فشلت عملية الدفع',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              reason,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primaryAmber,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onContactSupport,
                icon: const Icon(Icons.support_agent),
                label: const Text('تواصل مع الدعم'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onCancel,
              child: const Text('إلغاء والعودة'),
            ),
          ],
        ),
      ),
    );
  }
}
