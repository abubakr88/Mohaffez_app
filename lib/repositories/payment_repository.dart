// lib/repositories/payment_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payment_model.dart';
import '../models/subscription_model.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(FirebaseFirestore.instance);
});

class PaymentRepository {
  final FirebaseFirestore _firestore;

  PaymentRepository(this._firestore);

  // ── Payment CRUD ────────────────────────────────────────────────────────────

  Future<String> createPayment(PaymentModel payment) async {
    final docRef = await _firestore.collection('payments').add({
      ...payment.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<PaymentModel?> getPayment(String paymentId) async {
    final doc =
        await _firestore.collection('payments').doc(paymentId).get();
    if (!doc.exists) return null;
    return PaymentModel.fromFirestore(doc);
  }

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

  Future<void> updatePaymentGatewayInfo(
    String paymentId, {
    String? orderId,
    String? paymentKey,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (orderId != null) updateData['gatewayOrderId'] = orderId;
    if (paymentKey != null) {
      updateData['transactionReference'] = paymentKey;
    }
    await _firestore
        .collection('payments')
        .doc(paymentId)
        .update(updateData);
  }

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

  // ── Subscription management ─────────────────────────────────────────────────

  Stream<List<SubscriptionModel>> watchStudentSubscriptions(
      String studentId) {
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

  Future<SubscriptionModel?> getSubscription(
      String subscriptionId) async {
    final doc = await _firestore
        .collection('subscriptions')
        .doc(subscriptionId)
        .get();
    if (!doc.exists) return null;
    return SubscriptionModel.fromFirestore(doc);
  }

  /// Check if a student has an active subscription with a mohaffez.
  ///
  /// FIX: added optional [sessionType] filter. A student can hold both an
  /// 'online' and a 'home' bundle for the same teacher; without this filter
  /// the wrong subscription is returned and the CF rejects it with
  /// `failed-precondition`. Passing null preserves backward compatibility.
  Future<SubscriptionModel?> getActiveSubscription(
    String studentId,
    String mohaffezId, {
    String? sessionType, // FIX: optional filter
  }) async {
    try {
      debugPrint(
          '🔍 getActiveSubscription: studentId=$studentId, mohaffezId=$mohaffezId, sessionType=$sessionType');

      var query = _firestore
          .collection('subscriptions')
          .where('studentId', isEqualTo: studentId)
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('status', isEqualTo: 'active')
          .where('remainingSessions', isGreaterThan: 0);

      // FIX: only add sessionType filter when provided
      if (sessionType != null && sessionType.isNotEmpty) {
        query = query.where('sessionType', isEqualTo: sessionType);
      }

      final snapshot = await query.limit(1).get();

      debugPrint(
          '🔍 getActiveSubscription: found ${snapshot.docs.length} docs');
      if (snapshot.docs.isNotEmpty) {
        debugPrint(
            '🔍 getActiveSubscription doc: ${snapshot.docs.first.data()}');
      }

      if (snapshot.docs.isEmpty) return null;

      final subscription =
          SubscriptionModel.fromFirestore(snapshot.docs.first);

      // Guard against showing an expired subscription in the UI.
      // Do NOT write status here — expiry transitions are Cloud Function–only.
      if (subscription.expiryDate != null &&
          subscription.expiryDate!.isBefore(DateTime.now())) {
        return null;
      }

      return subscription;
    } catch (e, stack) {
      debugPrint('❌ getActiveSubscription FAILED: $e');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

}
