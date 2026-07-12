import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_model.dart';

class StudentProfileModel {
  final String id;
  final String ownerId;
  final String name;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? photoUrl;
  final String relationship;
  final String? level;
  final String? notes;
  final bool isActive;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StudentProfileModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.gender,
    this.dateOfBirth,
    this.photoUrl,
    this.relationship = 'self',
    this.level,
    this.notes,
    this.isActive = true,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  factory StudentProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StudentProfileModel.fromMap(data, doc.id);
  }

  factory StudentProfileModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime? dateFrom(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return StudentProfileModel(
      id: id,
      ownerId: (data['ownerId'] ?? data['guardianId'] ?? '').toString(),
      name: (data['name'] ?? '').toString().trim(),
      gender: data['gender'] as String?,
      dateOfBirth: dateFrom(data['dateOfBirth']),
      photoUrl: data['photoUrl'] as String?,
      relationship: (data['relationship'] ?? 'child').toString(),
      level: data['level'] as String?,
      notes: data['notes'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      isDefault: data['isDefault'] as bool? ?? false,
      createdAt: dateFrom(data['createdAt']),
      updatedAt: dateFrom(data['updatedAt']),
    );
  }

  factory StudentProfileModel.fromUser(UserModel user) {
    return StudentProfileModel(
      id: 'self',
      ownerId: user.uid,
      name: user.name,
      gender: user.gender,
      dateOfBirth: user.dateOfBirth,
      photoUrl: user.photoUrl,
      relationship: 'self',
      isActive: true,
      isDefault: true,
      createdAt: user.createdAt,
    );
  }

  int? get age {
    final birthDate = dateOfBirth;
    if (birthDate == null) return null;
    final today = DateTime.now();
    var years = today.year - birthDate.year;
    final hadBirthdayThisYear = today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthdayThisYear) years--;
    return years >= 0 ? years : null;
  }

  bool get isPersisted => id != 'self';

  Map<String, dynamic> toFirestore({
    bool includeServerTimestamps = true,
    bool creating = false,
  }) {
    return {
      'ownerId': ownerId,
      'name': name.trim(),
      if (gender != null && gender!.trim().isNotEmpty) 'gender': gender,
      if (dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(dateOfBirth!),
      if (photoUrl != null && photoUrl!.trim().isNotEmpty) 'photoUrl': photoUrl,
      'relationship': relationship,
      if (level != null && level!.trim().isNotEmpty) 'level': level,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
      'isActive': isActive,
      'isDefault': isDefault,
      if (includeServerTimestamps && creating)
        'createdAt': FieldValue.serverTimestamp(),
      if (includeServerTimestamps) 'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toBookingSnapshot(UserModel guardian) {
    return {
      'guardianId': guardian.uid,
      'guardianName': guardian.name,
      'studentProfileId': id,
      'studentProfileName': name,
      if (gender != null) 'studentProfileGender': gender,
      if (photoUrl != null && photoUrl!.trim().isNotEmpty)
        'studentProfilePhotoUrl': photoUrl!.trim(),
      if (dateOfBirth != null)
        'studentProfileBirthDate': Timestamp.fromDate(dateOfBirth!),
      if (age != null) 'studentAge': age,
    };
  }

  Map<String, dynamic> toCallableBookingSnapshot(UserModel guardian) {
    final snapshot = toBookingSnapshot(guardian);
    if (dateOfBirth != null) {
      snapshot['studentProfileBirthDate'] =
          dateOfBirth!.toUtc().toIso8601String();
    }
    return snapshot;
  }

  StudentProfileModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? gender,
    DateTime? dateOfBirth,
    String? photoUrl,
    String? relationship,
    String? level,
    String? notes,
    bool? isActive,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentProfileModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      photoUrl: photoUrl ?? this.photoUrl,
      relationship: relationship ?? this.relationship,
      level: level ?? this.level,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static StudentProfileModel resolveActive(
    UserModel user,
    List<StudentProfileModel> profiles,
  ) {
    return resolveActiveOrNull(user, profiles) ??
        StudentProfileModel.fromUser(user);
  }

  static StudentProfileModel? resolveActiveOrNull(
    UserModel user,
    List<StudentProfileModel> profiles, {
    bool allowSelfFallback = true,
  }) {
    if (user.activeStudentProfileId == 'self') {
      return allowSelfFallback ? StudentProfileModel.fromUser(user) : null;
    }

    StudentProfileModel? firstWhereOrNull(
      bool Function(StudentProfileModel profile) test,
    ) {
      for (final profile in profiles) {
        if (test(profile)) return profile;
      }
      return null;
    }

    final active = firstWhereOrNull(
      (profile) =>
          profile.isActive && profile.id == user.activeStudentProfileId,
    );
    if (active != null) return active;

    final defaultProfile = firstWhereOrNull(
      (profile) => profile.isActive && profile.isDefault,
    );
    if (defaultProfile != null) return defaultProfile;

    final first = firstWhereOrNull((profile) => profile.isActive);
    return first ??
        (allowSelfFallback ? StudentProfileModel.fromUser(user) : null);
  }
}
