// lib/providers/payment_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_model.dart';
import '../models/subscription_model.dart';
import '../models/pricing_plan_model.dart';
import '../repositories/payment_repository.dart';
import '../services/payment_service.dart';

// Providers
final studentSubscriptionsProvider =
    StreamProvider.family<List<SubscriptionModel>, String>((ref, studentId) {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.watchStudentSubscriptions(studentId);
});

final studentPaymentsProvider =
    StreamProvider.family<List<PaymentModel>, String>((ref, studentId) {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.watchStudentPayments(studentId);
});

final paymentStatusProvider =
    StreamProvider.family<PaymentModel?, String>((ref, paymentId) {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.watchPaymentStatus(paymentId);
});

final activeSubscriptionProvider = FutureProvider.family<
    SubscriptionModel?, Map<String, String>>((ref, params) async {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.getActiveSubscription(
    params['studentId']!,
    params['mohaffezId']!,
  );
});

class PaymentStartResult {
  final String paymentId;
  final String paymentUrl;

  const PaymentStartResult({
    required this.paymentId,
    required this.paymentUrl,
  });
}

final paymentActionsProvider =
    StateNotifierProvider<PaymentActionsNotifier, AsyncValue<void>>(
  (ref) {
    return PaymentActionsNotifier(
      ref.watch(paymentRepositoryProvider),
      ref.watch(paymentServiceProvider),
    );
  },
);

class PaymentActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final PaymentRepository _repository;
  final PaymentService _paymentService;

  PaymentActionsNotifier(this._repository, this._paymentService)
      : super(const AsyncValue.data(null));

  Future<PaymentStartResult?> startPaymentAndHandleResult({
    required PaymentModel basePayment,
    required PricingPlanModel plan,
    Map<String, dynamic>? extraMetadata,
  }) async {
    state = const AsyncValue.loading();

    try {
      final mergedMetadata = <String, dynamic>{
        if (basePayment.metadata != null) ...basePayment.metadata!,
        if (extraMetadata != null) ...extraMetadata,
        'planId': plan.id,
        'planTitle': plan.title,
        'planType': plan.type.name,
        'planMode': plan.mode.name,
        'sessionsCount': plan.sessionsCount,
        'priceEGP': plan.priceEGP,
      };

      final pendingPayment = basePayment.copyWith(
        status: PaymentStatus.pending,
        method: PaymentMethod.card,
        gateway: PaymentGateway.paymob,
        metadata: mergedMetadata,
      );

      final paymentId = await _repository.createPayment(pendingPayment);

      final gatewayResult = await _paymentService.initiatePayment(
        paymentId: paymentId,
        amount: pendingPayment.amount,
        studentEmail: pendingPayment.studentEmail,
        studentPhone: pendingPayment.studentPhone,
        studentName: pendingPayment.studentName,
      );

      if (gatewayResult['success'] != true) {
        await _repository.updatePaymentStatus(
          paymentId,
          PaymentStatus.failed,
          failureReason: gatewayResult['error']?.toString(),
        );
        throw Exception(gatewayResult['error'] ?? 'Failed to create payment URL');
      }

      final paymentUrl = gatewayResult['paymentUrl'] as String;
      final orderId = gatewayResult['orderId']?.toString();
      final paymentKey = gatewayResult['paymentKey']?.toString();

      await _repository.updatePaymentGatewayInfo(
        paymentId,
        orderId: orderId,
        paymentKey: paymentKey,
      );

      state = const AsyncValue.data(null);
      return PaymentStartResult(
        paymentId: paymentId,
        paymentUrl: paymentUrl,
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<bool> useSubscriptionSession({
    required String subscriptionId,
    required String sessionId,
  }) async {
    try {
      await _repository.consumeSession(subscriptionId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
