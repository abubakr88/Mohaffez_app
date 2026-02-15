import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payment_model.dart';
import '../models/pricing_plan_model.dart';
import '../models/subscription_model.dart';
import '../repositories/payment_repository.dart';
import '../services/payment_service.dart';

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

final activeSubscriptionProvider =
    FutureProvider.family<SubscriptionModel?, Map<String, String>>(
        (ref, params) async {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.getActiveSubscription(
      params['studentId']!, params['mohaffezId']!);
});

class PaymentStartResult {
  final String paymentId;
  final String paymentUrl;
  final String? sessionId;

  const PaymentStartResult({
    required this.paymentId,
    required this.paymentUrl,
    this.sessionId,
  });
}

final paymentActionsProvider =
    StateNotifierProvider<PaymentActionsNotifier, AsyncValue<void>>((ref) {
  return PaymentActionsNotifier(
    ref.watch(paymentRepositoryProvider),
    ref.watch(paymentServiceProvider),
    FirebaseFirestore.instance,
  );
});

class PaymentActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final PaymentRepository _repository;
  final PaymentService _paymentService;
  final FirebaseFirestore _firestore;

  PaymentActionsNotifier(
      this._repository, this._paymentService, this._firestore)
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

      // FREE SESSION FLOW (100% promo code)
      if (basePayment.amount <= 0.01) {
        final freePayment = basePayment.copyWith(
          status: PaymentStatus.pending,
          method: PaymentMethod.cash,
          gateway: PaymentGateway.manual,
          metadata: mergedMetadata,
          paidAt: DateTime.now(),
        );

        final paymentId = await _repository.createPayment(freePayment);
        
        // Update payment to completed
        await _firestore.collection('payments').doc(paymentId).update({
          'status': 'completed',
          'method': 'cash',
          'gateway': 'manual',
          'notes': 'Free session via promo code',
          'paidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        String? sessionId;
        
        // Handle booking confirmation for free session
        if (mergedMetadata['confirmBooking'] == true &&
            mergedMetadata['requestId'] != null) {
          final requestId = mergedMetadata['requestId'] as String;
          final sessionDetails =
              (mergedMetadata['sessionDetails'] as Map<String, dynamic>?) ??
                  <String, dynamic>{};

          // Get request data
          final requestSnapshot = await _firestore
              .collection('sessionRequests')
              .doc(requestId)
              .get();
          
          if (!requestSnapshot.exists) {
            throw Exception('Session request not found');
          }
          
          final requestData = requestSnapshot.data() ?? <String, dynamic>{};

          final slotDate = sessionDetails['slotDate'] as Timestamp? ??
              requestData['slotDate'] as Timestamp?;
          final preferredTimeSlot =
              sessionDetails['preferredTimeSlot'] as String? ??
                  requestData['preferredTimeSlot'] as String? ??
                  '';
          final sessionType = sessionDetails['sessionType'] as String? ??
              requestData['sessionType'] as String? ??
              '';

          // ✅ FIX: Update sessionRequest with ONLY allowed fields
          // Must match Firestore security rules for free session flow
          final requestUpdateData = <String, dynamic>{
            'status': 'accepted',
            'isPaid': true,
            'paidAt': FieldValue.serverTimestamp(),
            'paymentId': paymentId,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          print('🔍 DEBUG: Updating sessionRequest $requestId');
          print('🔍 DEBUG: Update fields: ${requestUpdateData.keys}');
          print('🔍 DEBUG: Current status should be: pending');

          await _firestore
              .collection('sessionRequests')
              .doc(requestId)
              .update(requestUpdateData);

          // Create hafizSession
          final sessionData = <String, dynamic>{
            'requestId': requestId,
            'status': 'accepted',
            'isPaid': true,
            'paymentId': paymentId,
            'studentId': basePayment.studentId,
            'studentName': basePayment.studentName,
            'mohaffezId': basePayment.mohaffezId,
            'mohaffezName': basePayment.mohaffezName,
            'sessionType': sessionType,
            'sessionDate': slotDate,
            'preferredTimeSlot': preferredTimeSlot,
            'timeSlot': preferredTimeSlot,
            'location': sessionDetails['location'] ??
                requestData['imamAddressText'] ??
                requestData['location'],
            'createdAt': FieldValue.serverTimestamp(),
            'acceptedAt': FieldValue.serverTimestamp(),
          };

          // Add optional location fields if available
          if (requestData['imamAddressText'] != null) {
            sessionData['imamAddressText'] = requestData['imamAddressText'];
          }
          if (requestData['imamAddressLat'] != null) {
            sessionData['imamAddressLat'] = requestData['imamAddressLat'];
          }
          if (requestData['imamAddressLng'] != null) {
            sessionData['imamAddressLng'] = requestData['imamAddressLng'];
          }

          final sessionRef =
              await _firestore.collection('hafizSessions').add(sessionData);
          sessionId = sessionRef.id;

          // Remove slot from availability
          if (slotDate != null &&
              preferredTimeSlot.isNotEmpty &&
              sessionType.isNotEmpty) {
            await _removeSlotFromAvailability(
              mohaffezId: basePayment.mohaffezId,
              slotDate: slotDate,
              timeSlot: preferredTimeSlot,
              sessionType: sessionType,
            );
          }

          // Send notification to student
          await _firestore.collection('notifications').add({
            'userId': basePayment.studentId,
            'recipientId': basePayment.studentId,
            'senderId': basePayment.mohaffezId,
            'title': 'تم تأكيد الجلسة المجانية! 🎉',
            'body': 'تم تأكيد حجز جلستك مع ${basePayment.mohaffezName}',
            'type': 'session_confirmed',
            'isRead': false,
            'data': {
              'sessionId': sessionId,
              'requestId': requestId,
            },
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Log payment event
          await _firestore.collection('paymentEvents').add({
            'eventType': 'payment_completed',
            'paymentId': paymentId,
            'userId': basePayment.studentId,
            'data': {
              'amount': 0,
              'method': 'free',
              'promoCode': mergedMetadata['promoCode'],
              'sessionId': sessionId,
            },
            'metadata': {
              'source': 'client',
              'notes': 'Free session via promo code',
            },
            'timestamp': FieldValue.serverTimestamp(),
          });

          print('✅ SUCCESS: Free session confirmed - Session ID: $sessionId');
        }

        state = const AsyncValue.data(null);
        return PaymentStartResult(
            paymentId: paymentId, paymentUrl: '', sessionId: sessionId);
      }

      // PAID SESSION FLOW (Gateway payment)
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
        throw Exception(
            gatewayResult['error'] ?? 'Failed to create payment URL');
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
      return PaymentStartResult(paymentId: paymentId, paymentUrl: paymentUrl);
    } catch (e, stack) {
      print('❌ ERROR in startPaymentAndHandleResult: $e');
      print('Stack trace: $stack');
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

  Future<void> _removeSlotFromAvailability({
    required String mohaffezId,
    required Timestamp slotDate,
    required String timeSlot,
    required String sessionType,
  }) async {
    // Note: This check prevents students from modifying mohaffez availability
    // Only the mohaffez themselves or cloud functions should do this
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    
    // For free sessions, we skip this check since Cloud Functions will handle it
    // Or we can remove this slot right away if the student is confirming
    // Comment this out if you want students to be able to book:
    // if (currentUid != mohaffezId) {
    //   return;
    // }

    final date = slotDate.toDate();
    final dayOfWeek = date.weekday;

    final availabilitySnapshot = await _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('availability')
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .limit(1)
        .get();

    if (availabilitySnapshot.docs.isEmpty) {
      print('⚠️ No availability document found for dayOfWeek: $dayOfWeek');
      return;
    }

    final availabilityDoc = availabilitySnapshot.docs.first;
    final data = availabilityDoc.data();
    final timeSlots = List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);

    var updated = false;
    for (final slot in timeSlots) {
      final slotTime = '${slot['startTime']}-${slot['endTime']}';
      if (slotTime == timeSlot &&
          slot['sessionType'] == sessionType &&
          slot['enabled'] == true) {
        slot['enabled'] = false;
        updated = true;
        print('✅ Slot disabled: $slotTime ($sessionType)');
        break;
      }
    }

    if (updated) {
      await availabilityDoc.reference.update({
        'timeSlots': timeSlots,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Availability updated successfully');
    } else {
      print('⚠️ Slot not found or already disabled');
    }
  }
}
