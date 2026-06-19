import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentServiceProvider = Provider((ref) {
  return PaymentService();
});

class PaymentService {
  // Flash intention creation is always server-side. Keeping the legacy API
  // fallback here allowed stale web bundles to create payments that did not
  // use the configured Flash notification URL.
  static const String _paymobIntegrationId =
      String.fromEnvironment('PAYMOB_INTEGRATION_ID');

  /// Main method: Initiate payment
  Future<Map<String, dynamic>> initiatePayment({
    required String paymentId,
    required double amount,
    required String studentEmail,
    required String studentPhone,
    required String studentName,
  }) async {
    try {
      return await _initiateFlashPayment(
        amount: amount,
        paymentId: paymentId,
        studentEmail: studentEmail,
        studentPhone: studentPhone,
        studentName: studentName,
      );
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _initiateFlashPayment({
    required String paymentId,
    required double amount,
    required String studentEmail,
    required String studentPhone,
    required String studentName,
  }) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('createPaymobIntention');
    final response = await callable.call<Map<String, dynamic>>({
      'paymentId': paymentId,
      'amount': amount,
      'integrationId': _parsedIntegrationId,
      'studentEmail': _safeEmail(studentEmail),
      'studentPhone': _normalizePhone(studentPhone),
      'studentName':
          studentName.trim().isNotEmpty ? studentName.trim() : 'Student',
    });

    final data = Map<String, dynamic>.from(response.data);
    if (data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'فشل إنشاء رابط الدفع');
    }

    return {
      'success': true,
      'paymentUrl': data['paymentUrl']?.toString() ?? '',
      'orderId': data['orderId']?.toString(),
      'paymentKey': data['clientSecret']?.toString(),
    };
  }

  int get _parsedIntegrationId {
    final asInt = int.tryParse(_paymobIntegrationId.trim());
    if (asInt != null) return asInt;
    throw Exception('PAYMOB_INTEGRATION_ID غير صحيح');
  }

  String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '01000000000';
    return trimmed;
  }

  String _safeEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return 'customer@mohafezy.com';
    }
    return trimmed;
  }
}
