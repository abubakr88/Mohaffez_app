// lib/repositories/payment_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payment_model.dart';
import '../models/subscription_model.dart';

final paymentRepositoryProvider = Provider((ref) {
  return PaymentRepository(FirebaseFirestore.instance);
});

class PaymentRepository {
  final FirebaseFirestore _firestore;

  PaymentRepository(this._firestore);

  // Create payment record
  Future<String> createPayment(PaymentModel payment) async {
    final docRef = await _firestore.collection('payments').add({
      ...payment.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Get payment by ID
  Future<PaymentModel?> getPayment(String paymentId) async {
    final doc = await _firestore.collection('payments').doc(paymentId).get();
    if (!doc.exists) return null;
    return PaymentModel.fromFirestore(doc);
  }

  // Watch payment status (for real-time updates from webhook)
  Stream<PaymentModel?> watchPaymentStatus(String paymentId) {
    return _firestore
        .collection('payments')
        .doc(paymentId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return PaymentModel.fromFirestore(doc);
    });
  }

  // Update payment status
  Future<void> updatePaymentStatus(
    String paymentId,
    PaymentStatus status, {
    String? transactionReference,
    String? gatewayTransactionId,
    String? failureReason,
  }) async {
    final updateData = <String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == PaymentStatus.completed) {
      updateData['paidAt'] = FieldValue.serverTimestamp();
    }

    if (transactionReference != null) {
      updateData['transactionReference'] = transactionReference;
    }

    if (gatewayTransactionId != null) {
      updateData['gatewayTransactionId'] = gatewayTransactionId;
    }

    if (failureReason != null) {
      updateData['failureReason'] = failureReason;
    }

    await _firestore.collection('payments').doc(paymentId).update(updateData);
  }

  // Update gateway order info (called after initiating payment)
  Future<void> updatePaymentGatewayInfo(
    String paymentId, {
    String? orderId,
    String? paymentKey,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (orderId != null) {
      updateData['gatewayOrderId'] = orderId;
    }

    if (paymentKey != null) {
      updateData['transactionReference'] = paymentKey;
    }

    await _firestore.collection('payments').doc(paymentId).update(updateData);
  }

  // Get student payment history
  Stream<List<PaymentModel>> watchStudentPayments(String studentId) {
    return _firestore
        .collection('payments')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }

  // Get mohaffez earnings
  Stream<List<PaymentModel>> watchMohaffezEarnings(String mohaffezId) {
    return _firestore
        .collection('payments')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }

  // SUBSCRIPTION MANAGEMENT

  // Create subscription after successful payment
  Future<String> createSubscription(SubscriptionModel subscription) async {
    final docRef = await _firestore.collection('subscriptions').add({
      ...subscription.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Get active subscriptions for student
  Stream<List<SubscriptionModel>> watchStudentSubscriptions(String studentId) {
    return _firestore
        .collection('subscriptions')
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SubscriptionModel.fromFirestore(doc))
            .toList());
  }

  // Get specific subscription
  Future<SubscriptionModel?> getSubscription(String subscriptionId) async {
    final doc =
        await _firestore.collection('subscriptions').doc(subscriptionId).get();
    if (!doc.exists) return null;
    return SubscriptionModel.fromFirestore(doc);
  }

  // Consume session from subscription (transactional)
  Future<void> consumeSession(String subscriptionId) async {
    await _firestore.runTransaction((transaction) async {
      final subRef =
          _firestore.collection('subscriptions').doc(subscriptionId);
      final subDoc = await transaction.get(subRef);

      if (!subDoc.exists) {
        throw Exception('Subscription not found');
      }

      final subscription = SubscriptionModel.fromFirestore(subDoc);

      if (subscription.remainingSessions <= 0) {
        throw Exception('No sessions remaining');
      }

      final newRemaining = subscription.remainingSessions - 1;
      final newStatus = newRemaining == 0
          ? SubscriptionStatus.depleted
          : subscription.status;

      transaction.update(subRef, {
        'remainingSessions': newRemaining,
        'status': newStatus.name,
        'lastUsedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Check if student has active subscription with mohaffez
  Future<SubscriptionModel?> getActiveSubscription(
    String studentId,
    String mohaffezId,
  ) async {
    final snapshot = await _firestore
        .collection('subscriptions')
        .where('studentId', isEqualTo: studentId)
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'active')
        .where('remainingSessions', isGreaterThan: 0)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final subscription = SubscriptionModel.fromFirestore(snapshot.docs.first);

    // Check expiry
    if (subscription.expiryDate != null &&
        subscription.expiryDate!.isBefore(DateTime.now())) {
      // Mark as expired
      await _firestore
          .collection('subscriptions')
          .doc(subscription.id)
          .update({'status': SubscriptionStatus.expired.name});
      return null;
    }

    return subscription;
  }

  // Update subscription status
  Future<void> updateSubscriptionStatus(
    String subscriptionId,
    SubscriptionStatus status,
  ) async {
    await _firestore.collection('subscriptions').doc(subscriptionId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
