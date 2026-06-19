import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

enum _PaymentReturnState { success, failed, pending, unknown }

class PaymentReturnScreen extends StatelessWidget {
  const PaymentReturnScreen({
    super.key,
    required this.uri,
  });

  final Uri uri;

  _PaymentReturnState get _state {
    final params = uri.queryParameters;
    final success = params['success']?.toLowerCase();
    final pending = params['pending']?.toLowerCase();
    final errorOccurred =
        (params['error_occured'] ?? params['error_occurred'])?.toLowerCase();

    if (success == 'true' && pending != 'true' && errorOccurred != 'true') {
      return _PaymentReturnState.success;
    }
    if (pending == 'true') return _PaymentReturnState.pending;
    if (success == 'false' || errorOccurred == 'true') {
      return _PaymentReturnState.failed;
    }
    return _PaymentReturnState.unknown;
  }

  String? get _amountText {
    final amountCents = int.tryParse(uri.queryParameters['amount_cents'] ?? '');
    if (amountCents == null || amountCents <= 0) return null;
    return '${(amountCents / 100).toStringAsFixed(2)} جنيه';
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final isSuccess = state == _PaymentReturnState.success;
    final isFailed = state == _PaymentReturnState.failed;
    final isPending = state == _PaymentReturnState.pending;
    final title = isSuccess
        ? 'تم الدفع بنجاح'
        : isFailed
            ? 'لم يكتمل الدفع'
            : isPending
                ? 'الدفع قيد المعالجة'
                : 'تم الرجوع من Paymob';
    final message = isSuccess
        ? 'تم استلام نتيجة الدفع من Paymob. ارجع إلى نافذة التطبيق المفتوحة، وسيظهر تأكيد الحجز تلقائيا بعد وصول إشعار Paymob إلى الخادم.'
        : isFailed
            ? 'لم تكتمل عملية الدفع. يمكنك إغلاق هذه الصفحة والعودة إلى التطبيق للمحاولة مرة أخرى.'
            : isPending
                ? 'ما زالت العملية قيد المعالجة لدى Paymob. اترك نافذة التطبيق مفتوحة حتى يظهر التأكيد.'
                : 'تم الرجوع من صفحة الدفع. إذا كنت قد أكملت الدفع، انتظر ظهور التأكيد داخل التطبيق.';
    final color = isSuccess
        ? AppThemeConstants.success
        : isFailed
            ? AppThemeConstants.error
            : AppThemeConstants.secondary;
    final icon = isSuccess
        ? Icons.check_circle
        : isFailed
            ? Icons.error_outline
            : Icons.hourglass_top;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 84, color: color),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: AppThemeConstants.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_amountText != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.grey50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'المبلغ: $_amountText',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppThemeConstants.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go('/home'),
                            icon: const Icon(Icons.home_outlined),
                            label: const Text('فتح التطبيق'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'ملاحظة: تأكيد الحجز يتم من الخادم فقط، وليس من هذه الصفحة.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppThemeConstants.grey500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
