import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pricing_plan_model.dart';

final pricingRepositoryProvider = Provider<PricingRepository>((ref) {
  return PricingRepository(FirebaseFirestore.instance);
});

class PricingRepository {
  final FirebaseFirestore _firestore;

  PricingRepository(this._firestore);

  // Get all pricing plans for a mohaffez
  Stream<List<PricingPlanModel>> watchMohaffezPlans(String mohaffezId) {
    return _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('pricingPlans')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PricingPlanModel.fromFirestore(doc))
            .toList());
  }

  // Get active plans only
  Stream<List<PricingPlanModel>> watchActivePlans(String mohaffezId) {
    return _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('pricingPlans')
        .where('isActive', isEqualTo: true)
        .orderBy('priceEGP', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PricingPlanModel.fromFirestore(doc))
            .toList());
  }

  // Get specific plan
  Future<PricingPlanModel?> getPlan(String mohaffezId, String planId) async {
    final doc = await _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('pricingPlans')
        .doc(planId)
        .get();

    if (!doc.exists) return null;
    return PricingPlanModel.fromFirestore(doc);
  }

  // Create new plan
  Future<String> createPlan(PricingPlanModel plan) async {
    final docRef = await _firestore
        .collection('users')
        .doc(plan.mohaffezId)
        .collection('pricingPlans')
        .add({
      ...plan.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // Update plan
  Future<void> updatePlan(PricingPlanModel plan) async {
    if (plan.id == null) throw Exception('Plan ID is required for update');

    await _firestore
        .collection('users')
        .doc(plan.mohaffezId)
        .collection('pricingPlans')
        .doc(plan.id)
        .update({
      ...plan.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete plan
  Future<void> deletePlan(String mohaffezId, String planId) async {
    await _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('pricingPlans')
        .doc(planId)
        .delete();
  }

  // Toggle plan status
  Future<void> togglePlanStatus(
    String mohaffezId,
    String planId,
    bool isActive,
  ) async {
    await _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('pricingPlans')
        .doc(planId)
        .update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get all plans for a teacher (used for checking bundle/subscription availability)
  Future<List<PricingPlanModel>> getPlansForTeacher(String mohaffezId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('pricingPlans')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => PricingPlanModel.fromFirestore(doc))
        .toList();
  }
}
