import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository(this._firestore);

  Future<List<Map<String, dynamic>>> getAllUsers({String? roleFilter}) async {
    Query<Map<String, dynamic>> query = _firestore.collection('users');
    if (roleFilter != null && roleFilter.isNotEmpty) {
      query = query.where('role', isEqualTo: roleFilter);
    }

    final snap = await query.limit(500).get();
    return snap.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList();
  }

  Future<void> suspendUser(String userId, String adminUid, String reason,
      DateTime? expiresAt) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(userId);
    final suspensionRef = _firestore.collection('userSuspensions').doc(userId);

    batch.update(userRef, {
      'status': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
        suspensionRef,
        {
          'userId': userId,
          'suspendedBy': adminUid,
          'reason': reason,
          'suspendedAt': FieldValue.serverTimestamp(),
          'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
          'isActive': true,
        },
        SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> unsuspendUser(String userId, String adminUid) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(userId);
    final suspensionRef = _firestore.collection('userSuspensions').doc(userId);

    batch.update(userRef, {
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
        suspensionRef,
        {
          'isActive': false,
          'unsuspendedAt': FieldValue.serverTimestamp(),
          'unsuspendedBy': adminUid,
        },
        SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> deleteUserData(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);

    Future<void> deleteCollection(String path) async {
      final colSnap = await _firestore.collection(path).get();
      for (var i = 0; i < colSnap.docs.length; i += 400) {
        final chunk = colSnap.docs.skip(i).take(400);
        final batch = _firestore.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    await deleteCollection('users/$userId/availability');
    await deleteCollection('users/$userId/credentials');
    await deleteCollection('users/$userId/settings');
    await userRef.delete();
  }

  Future<void> updateUserRole(String userId, String newRole, String adminUid) {
    return _firestore.collection('users').doc(userId).update({
      'role': newRole,
      'roleUpdatedAt': FieldValue.serverTimestamp(),
      'roleUpdatedBy': adminUid,
    });
  }

  Stream<List<Map<String, dynamic>>> watchPendingCredentials() {
    return _firestore
        .collectionGroup('credentials')
        .where('status', isEqualTo: 'pending')
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => <String, dynamic>{
                  'id': d.id,
                  'userId': d.reference.parent.parent?.id,
                  ...d.data()
                })
            .toList());
  }

  Future<void> approveCredential(String userId, String credentialId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('credentials')
        .doc(credentialId)
        .update({
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectCredential(
      String userId, String credentialId, String reason) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('credentials')
        .doc(credentialId)
        .update({
      'status': 'rejected',
      'rejectionReason': reason,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchFailedOperations() {
    // WHY: Show only active failed operations and include legacy "pending" records.
    return _firestore
        .collection('failedOperations')
        .where('status', whereIn: ['pending-retry', 'pending', 'failed'])
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
            .toList());
  }

  Future<void> dismissFailedOperation(String operationId) {
    return _firestore.collection('failedOperations').doc(operationId).update({
      'status': 'dismissed',
      'dismissedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchAllPromoCodes() {
    return _firestore.collection('promoCodes').limit(200).snapshots().map((snap) => snap
        .docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList());
  }

  Future<void> createPromoCode(Map<String, dynamic> data) {
    return _firestore.collection('promoCodes').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'usedCount': data['usedCount'] ?? 0,
    });
  }

  Future<void> togglePromoCode(String promoId, bool isActive) {
    return _firestore.collection('promoCodes').doc(promoId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePromoCode(String promoId) {
    return _firestore.collection('promoCodes').doc(promoId).delete();
  }

  Stream<List<Map<String, dynamic>>> watchPaymentAnalytics() {
    return _firestore.collection('paymentAnalytics').snapshots().map((snap) =>
        snap.docs
            .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> watchActiveSlotLocks() {
    return _firestore
        .collection('slotLocks')
        .where('released', isEqualTo: false)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
            .toList());
  }
}
