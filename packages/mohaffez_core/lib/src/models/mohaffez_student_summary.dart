// lib/models/mohaffez_student_summary.dart

class MohaffezStudentSummary {
  final String studentId;
  final String studentName;
  final String? photoUrl;
  final DateTime? lastSessionDate;
  final String lastSessionStatus;
  final String hifzAssignment;
  final String murajaAssignment;
  final int sessionRating;
  final int sessionCount; // Pre-computed — no N+1 query
  final bool? previousHifzCompleted;
  final int previousHifzRating;
  final bool? previousMurajaCompleted;
  final int previousMurajaRating;
  final String? previousHifzFromAyah;
  final String? previousHifzToAyah;
  final String? previousMurajaFromAyah;
  final String? previousMurajaToAyah;
  final String? performanceNotes;

  const MohaffezStudentSummary({
    required this.studentId,
    required this.studentName,
    this.photoUrl,
    this.lastSessionDate,
    this.lastSessionStatus = 'accepted',
    this.hifzAssignment = '',
    this.murajaAssignment = '',
    this.sessionRating = 0,
    this.sessionCount = 0,
    this.previousHifzCompleted,
    this.previousHifzRating = 0,
    this.previousMurajaCompleted,
    this.previousMurajaRating = 0,
    this.previousHifzFromAyah,
    this.previousHifzToAyah,
    this.previousMurajaFromAyah,
    this.previousMurajaToAyah,
    this.performanceNotes,
  });

  MohaffezStudentSummary copyWith({int? sessionCount, String? photoUrl}) {
    return MohaffezStudentSummary(
      studentId: studentId,
      studentName: studentName,
      photoUrl: photoUrl ?? this.photoUrl,
      lastSessionDate: lastSessionDate,
      lastSessionStatus: lastSessionStatus,
      hifzAssignment: hifzAssignment,
      murajaAssignment: murajaAssignment,
      sessionRating: sessionRating,
      sessionCount: sessionCount ?? this.sessionCount,
      previousHifzCompleted: previousHifzCompleted,
      previousHifzRating: previousHifzRating,
      previousMurajaCompleted: previousMurajaCompleted,
      previousMurajaRating: previousMurajaRating,
      previousHifzFromAyah: previousHifzFromAyah,
      previousHifzToAyah: previousHifzToAyah,
      previousMurajaFromAyah: previousMurajaFromAyah,
      previousMurajaToAyah: previousMurajaToAyah,
      performanceNotes: performanceNotes,
    );
  }

  factory MohaffezStudentSummary.fromJson(Map<String, dynamic> json) {
    return MohaffezStudentSummary(
      studentId: json['studentId'] as String,
      studentName: json['studentName'] as String,
      photoUrl: json['photoUrl'] as String?,
      lastSessionDate: json['lastSessionDate'] != null
          ? DateTime.parse(json['lastSessionDate'] as String)
          : null,
      lastSessionStatus: json['lastSessionStatus'] as String? ?? 'accepted',
      hifzAssignment: json['hifzAssignment'] as String? ?? '',
      murajaAssignment: json['murajaAssignment'] as String? ?? '',
      sessionRating: json['sessionRating'] as int? ?? 0,
      sessionCount: json['sessionCount'] as int? ?? 0,
      previousHifzCompleted: json['previousHifzCompleted'] as bool?,
      previousHifzRating: json['previousHifzRating'] as int? ?? 0,
      previousMurajaCompleted: json['previousMurajaCompleted'] as bool?,
      previousMurajaRating: json['previousMurajaRating'] as int? ?? 0,
      previousHifzFromAyah: json['previousHifzFromAyah'] as String?,
      previousHifzToAyah: json['previousHifzToAyah'] as String?,
      previousMurajaFromAyah: json['previousMurajaFromAyah'] as String?,
      previousMurajaToAyah: json['previousMurajaToAyah'] as String?,
      performanceNotes: json['performanceNotes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'photoUrl': photoUrl,
      'lastSessionDate': lastSessionDate?.toIso8601String(),
      'lastSessionStatus': lastSessionStatus,
      'hifzAssignment': hifzAssignment,
      'murajaAssignment': murajaAssignment,
      'sessionRating': sessionRating,
      'sessionCount': sessionCount,
      'previousHifzCompleted': previousHifzCompleted,
      'previousHifzRating': previousHifzRating,
      'previousMurajaCompleted': previousMurajaCompleted,
      'previousMurajaRating': previousMurajaRating,
      'previousHifzFromAyah': previousHifzFromAyah,
      'previousHifzToAyah': previousHifzToAyah,
      'previousMurajaFromAyah': previousMurajaFromAyah,
      'previousMurajaToAyah': previousMurajaToAyah,
      'performanceNotes': performanceNotes,
    };
  }
}
