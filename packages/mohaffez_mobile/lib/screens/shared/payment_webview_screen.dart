import 'dart:async';
import 'package:mohaffez_core/mohaffez_core.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/paymob_callback_parser.dart';

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
  bool _externalPaymentOpened = false;
  BuildContext? _successDialogContext;
  ProviderSubscription<AsyncValue<PaymentModel?>>? _paymentStatusSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initWebView();
    }
    _timeoutTimer = Timer(const Duration(minutes: kIsWeb ? 10 : 3), () {
      if (!paymentCompleted && mounted) {
        _showTimeoutDialog();
      }
    });
    _listenToPaymentStatus();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPaymentExternally();
      });
    }
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
              return NavigationDecision.prevent;
            }
            if (_isFailureUrl(request.url)) {
              _showFailureDialog('فشلت عملية الدفع');
              return NavigationDecision.prevent;
            }
            if (_isPaymobReturnUrl(request.url)) {
              if (mounted) setState(() => loadingProgress = 100);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (paymentCompleted || error.isForMainFrame == false) return;
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

  bool _isSuccessUrl(String url) =>
      parsePaymobCallback(url) == PaymobCallbackResult.success;

  bool _isFailureUrl(String url) =>
      parsePaymobCallback(url) == PaymobCallbackResult.failure;

  bool _isPaymobReturnUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.endsWith('mohafezy.com') && uri.path == '/payment/return';
  }

  Future<void> _openPaymentExternally() async {
    final uri = Uri.tryParse(widget.paymentUrl);
    if (uri == null) {
      _showFailureDialog('رابط الدفع غير صالح');
      return;
    }

    final opened = await launchUrl(
      uri,
      webOnlyWindowName: '_blank',
    );

    if (!mounted) return;
    setState(() => _externalPaymentOpened = opened);

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح صفحة الدفع')),
      );
    }
  }

  void _retryPayment() {
    if (kIsWeb) {
      _openPaymentExternally();
      return;
    }
    setState(() => loadingProgress = 0);
    controller.reload();
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
      builder: (ctx) {
        _successDialogContext = ctx;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                style: TextStyle(
                    fontSize: 14, color: AppThemeConstants.textSecondary),
              ),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || !context.mounted) return;
      try {
        final dialogContext = _successDialogContext;
        if (dialogContext != null && dialogContext.mounted) {
          Navigator.of(dialogContext, rootNavigator: true).pop();
        }
        _successDialogContext = null;
        context.pop(true);
      } catch (e) {
        // Payment already succeeded; if navigation changed underneath us,
        // avoid trapping the user behind a stale success dialog.
        debugPrint('PaymentWebViewScreen: success close failed: $e');
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
              _retryPayment();
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
        body: kIsWeb ? _buildWebPaymentBody() : _buildMobileWebViewBody(),
      ),
    );
  }

  Widget _buildWebPaymentBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.open_in_new,
                size: 72,
                color: AppThemeConstants.secondary,
              ),
              const SizedBox(height: 18),
              const Text(
                'أكمل الدفع في صفحة Paymob',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _externalPaymentOpened
                    ? 'تم فتح صفحة الدفع. بعد إتمام العملية سيظهر التأكيد هنا تلقائياً.'
                    : 'اضغط لفتح صفحة الدفع، واترك هذه الصفحة مفتوحة حتى يتم التأكيد.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppThemeConstants.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openPaymentExternally,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    _externalPaymentOpened
                        ? 'فتح صفحة الدفع مرة أخرى'
                        : 'فتح صفحة الدفع',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const CircularProgressIndicator(
                color: AppThemeConstants.secondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'في انتظار تأكيد الدفع...',
                style: TextStyle(color: AppThemeConstants.grey600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileWebViewBody() {
    return Stack(
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
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppThemeConstants.success),
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
                    style: const TextStyle(
                        fontSize: 14, color: AppThemeConstants.grey500),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      value: loadingProgress / 100,
                      minHeight: 8,
                      backgroundColor: AppThemeConstants.grey200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppThemeConstants.success),
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
    );
  }
}
