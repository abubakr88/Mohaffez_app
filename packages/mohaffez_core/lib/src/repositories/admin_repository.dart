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

  /// Teachers awaiting account verification.
  /// A verification request is a `users` doc with role 'mohaffez' and
  /// status 'pending_approval' (set on setup completion by the mobile app).
  /// Ordered by submission time (oldest first) using the deployed
  /// [role + status + approvalSubmittedAt] composite index.
  Stream<List<Map<String, dynamic>>> watchPendingTeachers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'mohaffez')
        .where('status', isEqualTo: 'pending_approval')
        .orderBy('approvalSubmittedAt')
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
            .toList());
  }

  /// Users marked by any known review/risk flag.
  ///
  /// This intentionally filters client-side because older documents do not use
  /// a single flag field yet. The dashboard queue remains read-only and links
  /// admins to the users page for manual review.
  Stream<List<Map<String, dynamic>>> watchFlaggedUsers() {
    return _firestore.collection('users').limit(500).snapshots().map((snap) {
      return snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .where(_isFlaggedUser)
          .toList();
    });
  }

  /// Single user document by id (for the admin profile/detail page).
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return <String, dynamic>{'id': doc.id, ...?doc.data()};
  }

  /// All sessions for a teacher, for profile statistics (aggregated client-side).
  /// Single equality filter on `mohaffezId` uses the automatic single-field index.
  Future<List<Map<String, dynamic>>> getTeacherSessions(
      String teacherId) async {
    final snap = await _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: teacherId)
        .limit(1000)
        .get();
    return snap.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList();
  }

  /// One-shot read of a single user's submitted credentials (for review).
  Future<List<Map<String, dynamic>>> getUserCredentials(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('credentials')
        .get();
    return snap.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList();
  }

  /// One-shot read of a teacher's pricing plans for the admin review screen.
  Future<List<Map<String, dynamic>>> getTeacherPricingPlans(
      String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('pricingPlans')
        .get();
    final plans = snap.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList();
    plans.sort((a, b) => _compareTs(b['createdAt'], a['createdAt']));
    return plans;
  }

  /// One-shot read of a teacher's weekly availability for admin review.
  Future<List<Map<String, dynamic>>> getTeacherAvailability(
      String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('availability')
        .get();
    final availability = snap.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList();
    availability.sort((a, b) {
      final aDay = (a['dayOfWeek'] as num?)?.toInt() ?? 99;
      final bDay = (b['dayOfWeek'] as num?)?.toInt() ?? 99;
      return aDay.compareTo(bDay);
    });
    return availability;
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
    return _firestore.collection('promoCodes').limit(200).snapshots().map(
        (snap) => snap.docs
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

int _compareTs(dynamic a, dynamic b) {
  DateTime? toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  final da = toDate(a);
  final db = toDate(b);
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return da.compareTo(db);
}

bool _isFlaggedUser(Map<String, dynamic> user) {
  final status = (user['status'] as String? ?? '').toLowerCase();
  if (status == 'flagged' ||
      status == 'suspicious' ||
      status == 'under_review' ||
      status == 'security_review') {
    return true;
  }

  for (final key in const [
    'isSuspicious',
    'riskFlag',
    'needsAdminReview',
    'adminReviewRequired',
    'paymentReviewRequired',
  ]) {
    if (user[key] == true) return true;
  }

  return false;
}
