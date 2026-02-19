// lib/models/mohaffez_student_summary.dart

class MohaffezStudentSummary {
  final String studentId;
  final String studentName;
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
  final String? performanceNotes;

  const MohaffezStudentSummary({
    required this.studentId,
    required this.studentName,
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
    this.performanceNotes,
  });

  MohaffezStudentSummary copyWith({int? sessionCount}) {
    return MohaffezStudentSummary(
      studentId: studentId,
      studentName: studentName,
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
      performanceNotes: performanceNotes,
    );
  }
}
