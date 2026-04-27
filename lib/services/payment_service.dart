// lib/services/payment_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';

final paymentServiceProvider = Provider((ref) {
  return PaymentService();
});

class PaymentService {
  // Paymob credentials (store in .env file)
  static const String _paymobApiKey = String.fromEnvironment('PAYMOB_API_KEY');
  static const String _paymobIntegrationId = String.fromEnvironment('PAYMOB_INTEGRATION_ID');
  static const String _paymobIframeId = String.fromEnvironment('PAYMOB_IFRAME_ID');
  static const String _paymobHmacSecret = String.fromEnvironment('PAYMOB_HMAC_SECRET');

  static const String _baseUrl = 'https://accept.paymob.com/api';

  /// Step 1: Get authentication token
  Future<String> _getAuthToken() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/tokens'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'api_key': _paymobApiKey}),
    );

    if (response.statusCode != 201) {
      throw Exception('فشل الحصول على رمز المصادقة');
    }

    final data = jsonDecode(response.body);
    return data['token'];
  }

  /// Step 2: Register order
  Future<String> _registerOrder({
    required String authToken,
    required double amount,
    required String paymentId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/ecommerce/orders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'auth_token': authToken,
        'delivery_needed': 'false',
        'amount_cents': (amount * 100).toInt(), // Convert to cents
        'currency': 'EGP',
        'merchant_order_id': paymentId,
        'items': [],
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('فشل تسجيل الطلب');
    }

    final data = jsonDecode(response.body);
    return data['id'].toString();
  }

  /// Step 3: Get payment key
  Future<String> _getPaymentKey({
    required String authToken,
    required String orderId,
    required double amount,
    required String studentEmail,
    required String studentPhone,
    required String studentName,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/acceptance/payment_keys'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'auth_token': authToken,
        'amount_cents': (amount * 100).toInt(),
        'expiration': 3600,
        'order_id': orderId,
        'billing_data': {
          'apartment': 'NA',
          'email': studentEmail,
          'floor': 'NA',
          'first_name': studentName.split(' ').first,
          'street': 'NA',
          'building': 'NA',
          'phone_number': studentPhone,
          'shipping_method': 'NA',
          'postal_code': 'NA',
          'city': 'NA',
          'country': 'EG',
          'last_name': studentName.split(' ').length > 1
              ? studentName.split(' ').last
              : studentName,
          'state': 'NA',
        },
        'currency': 'EGP',
        'integration_id': _paymobIntegrationId,
        'lock_order_when_paid': 'false',
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('فشل الحصول على مفتاح الدفع');
    }

    final data = jsonDecode(response.body);
    return data['token'];
  }

  /// Main method: Initiate payment
  Future<Map<String, dynamic>> initiatePayment({
    required String paymentId,
    required double amount,
    required String studentEmail,
    required String studentPhone,
    required String studentName,
  }) async {
    try {
      // Step 1: Get auth token
      final authToken = await _getAuthToken();

      // Step 2: Register order
      final orderId = await _registerOrder(
        authToken: authToken,
        amount: amount,
        paymentId: paymentId,
      );

      // Step 3: Get payment key
      final paymentKey = await _getPaymentKey(
        authToken: authToken,
        orderId: orderId,
        amount: amount,
        studentEmail: studentEmail,
        studentPhone: studentPhone,
        studentName: studentName,
      );

      // Step 4: Build payment URL
      final paymentUrl =
          'https://accept.paymob.com/api/acceptance/iframes/$_paymobIframeId?payment_token=$paymentKey';

      return {
        'success': true,
        'paymentUrl': paymentUrl,
        'orderId': orderId,
        'paymentKey': paymentKey,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Verify Paymob HMAC (for backend webhook use)
  bool verifyPaymobHmac({
    required Map<String, dynamic> data,
    required String receivedHmac,
  }) {
    // Paymob HMAC calculation - concatenate specific fields in order
    final hmacString = [
      data['amount_cents']?.toString() ?? '',
      data['created_at']?.toString() ?? '',
      data['currency']?.toString() ?? '',
      data['error_occured']?.toString() ?? 'false',
      data['has_parent_transaction']?.toString() ?? 'false',
      data['id']?.toString() ?? '',
      data['integration_id']?.toString() ?? '',
      data['is_3d_secure']?.toString() ?? 'false',
      data['is_auth']?.toString() ?? 'false',
      data['is_capture']?.toString() ?? 'false',
      data['is_refunded']?.toString() ?? 'false',
      data['is_standalone_payment']?.toString() ?? 'false',
      data['is_voided']?.toString() ?? 'false',
      data['order']?['id']?.toString() ?? '',
      data['owner']?.toString() ?? '',
      data['pending']?.toString() ?? 'false',
      data['source_data']?['pan']?.toString() ?? 'NA',
      data['source_data']?['sub_type']?.toString() ?? 'NA',
      data['source_data']?['type']?.toString() ?? 'NA',
      data['success']?.toString() ?? 'false',
    ].join('');

    final calculatedHmac = Hmac(sha512, utf8.encode(_paymobHmacSecret)).convert(utf8.encode(hmacString)).toString();

    return calculatedHmac == receivedHmac;
  }

}
