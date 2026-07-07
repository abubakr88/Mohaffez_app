import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/student_profile_model.dart';

final studentProfileRepositoryProvider = Provider<StudentProfileRepository>(
  (ref) => StudentProfileRepository(FirebaseFirestore.instance),
);

class StudentProfileRepository {
  final FirebaseFirestore _firestore;

  StudentProfileRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _collection(String ownerId) {
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('studentProfiles');
  }

  Stream<List<StudentProfileModel>> watchProfiles(String ownerId) {
    return _collection(ownerId).orderBy('createdAt').snapshots().map(
        (snapshot) => snapshot.docs
            .map(StudentProfileModel.fromFirestore)
            .where((profile) => profile.name.trim().isNotEmpty)
            .toList());
  }

  Future<List<StudentProfileModel>> getProfiles(String ownerId) async {
    final snapshot = await _collection(ownerId).orderBy('createdAt').get();
    return snapshot.docs
        .map(StudentProfileModel.fromFirestore)
        .where((profile) => profile.name.trim().isNotEmpty)
        .toList();
  }

  Future<String> createProfile(StudentProfileModel profile) async {
    final doc = _collection(profile.ownerId).doc();
    final normalized = profile.copyWith(id: doc.id);
    await doc.set(normalized.toFirestore(creating: true));

    final userRef = _firestore.collection('users').doc(profile.ownerId);
    await userRef.set({
      'accountType': profile.relationship == 'self' ? 'individual' : 'guardian',
      'activeStudentProfileId': doc.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return doc.id;
  }

  Future<void> updateProfile(StudentProfileModel profile) async {
    if (!profile.isPersisted) {
      throw StateError('Cannot update an in-memory fallback profile');
    }
    await _collection(profile.ownerId)
        .doc(profile.id)
        .update(profile.toFirestore(creating: false));
  }

  Future<void> setActiveProfile({
    required String ownerId,
    required String profileId,
  }) async {
    await _firestore.collection('users').doc(ownerId).set({
      'activeStudentProfileId': profileId,
      'accountType': profileId == 'self' ? 'individual' : 'guardian',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> softDeleteProfile({
    required String ownerId,
    required String profileId,
  }) async {
    await _collection(ownerId).doc(profileId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final remaining = (await getProfiles(ownerId))
        .where((profile) => profile.id != profileId && profile.isActive)
        .toList();
    await _firestore.collection('users').doc(ownerId).set({
      'activeStudentProfileId':
          remaining.isNotEmpty ? remaining.first.id : null,
      'accountType': remaining.length > 1 ? 'guardian' : 'individual',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> ensureDefaultProfile({
    required String ownerId,
    required StudentProfileModel fallback,
  }) async {
    final existing = await getProfiles(ownerId);
    final activeExisting =
        existing.where((profile) => profile.isActive).toList();
    if (activeExisting.isNotEmpty) return activeExisting.first.id;

    final doc = _collection(ownerId).doc();
    final profile = fallback.copyWith(
      id: doc.id,
      relationship: 'self',
      isDefault: true,
      isActive: true,
    );
    await doc.set(profile.toFirestore(creating: true));
    await _firestore.collection('users').doc(ownerId).set({
      'accountType': 'individual',
      'activeStudentProfileId': doc.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return doc.id;
  }
}
