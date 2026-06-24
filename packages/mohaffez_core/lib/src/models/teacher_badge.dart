import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

enum TeacherBadgeType {
  foundingTeacher('foundingTeacher');

  const TeacherBadgeType(this.key);

  final String key;
}

class TeacherBadgeAssignment {
  const TeacherBadgeAssignment({
    this.enabled = false,
    this.grantedAt,
    this.grantedBy,
    this.grantedByName,
    this.reason,
    this.updatedAt,
    this.revokedAt,
    this.revokedBy,
    this.revocationReason,
  });

  final bool enabled;
  final DateTime? grantedAt;
  final String? grantedBy;
  final String? grantedByName;
  final String? reason;
  final DateTime? updatedAt;
  final DateTime? revokedAt;
  final String? revokedBy;
  final String? revocationReason;

  factory TeacherBadgeAssignment.fromJson(Object? value) {
    if (value is! Map) return const TeacherBadgeAssignment();
    final json = Map<String, dynamic>.from(value);
    return TeacherBadgeAssignment(
      enabled: json['enabled'] == true,
      grantedAt: _dateTime(json['grantedAt']),
      grantedBy: _text(json['grantedBy']),
      grantedByName: _text(json['grantedByName']),
      reason: _text(json['reason']),
      updatedAt: _dateTime(json['updatedAt']),
      revokedAt: _dateTime(json['revokedAt']),
      revokedBy: _text(json['revokedBy']),
      revocationReason: _text(json['revocationReason']),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (grantedAt != null) 'grantedAt': Timestamp.fromDate(grantedAt!),
        if (grantedBy != null) 'grantedBy': grantedBy,
        if (grantedByName != null) 'grantedByName': grantedByName,
        if (reason != null) 'reason': reason,
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
        if (revokedAt != null) 'revokedAt': Timestamp.fromDate(revokedAt!),
        if (revokedBy != null) 'revokedBy': revokedBy,
        if (revocationReason != null) 'revocationReason': revocationReason,
      };
}

class UserBadges {
  const UserBadges({
    this.foundingTeacher = const TeacherBadgeAssignment(),
  });

  final TeacherBadgeAssignment foundingTeacher;

  bool has(TeacherBadgeType type) => switch (type) {
        TeacherBadgeType.foundingTeacher => foundingTeacher.enabled,
      };

  factory UserBadges.fromJson(Object? value) {
    if (value is! Map) return const UserBadges();
    final json = Map<String, dynamic>.from(value);
    return UserBadges(
      foundingTeacher: TeacherBadgeAssignment.fromJson(
        json[TeacherBadgeType.foundingTeacher.key],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        TeacherBadgeType.foundingTeacher.key: foundingTeacher.toJson(),
      };
}

class UserBadgesConverter implements JsonConverter<UserBadges, Object?> {
  const UserBadgesConverter();

  @override
  UserBadges fromJson(Object? json) => UserBadges.fromJson(json);

  @override
  Object? toJson(UserBadges object) => object.toJson();
}

DateTime? _dateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
