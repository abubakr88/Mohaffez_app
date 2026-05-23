// lib/models/session_model.dart

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart'; // for TimestampConverter
import 'quran_mistake_model.dart'; // MistakeType + QuranMistake

part 'session_model.freezed.dart';
part 'session_model.g.dart';

// ==================== SESSION MODEL ====================
@freezed
class SessionModel with _$SessionModel {
  const factory SessionModel({
    String? id,
    required String mohaffezId,
    required String studentId,
    required String mohaffezName,
    required String studentName,
    required String sessionType,
    String? location,

    String? mohaffezPhone,
    double? imamAddressLat,
    double? imamAddressLng,
    String? preferredTimeSlot,

    @Default(1) int juzCount,
    String? hifzAssignment,
    String? murajaAssignment,

    bool? previousHifzCompleted,
    @Default(0) int previousHifzRating,
    bool? previousMurajaCompleted,
    @Default(0) int previousMurajaRating,

    String? performanceNotes,
    @Default(10) int sessionRating,
    @Default(0) int teacherRating,
    String? sessionNotes,

    @TimestampConverter() DateTime? sessionDate,
    @TimestampConverter() DateTime? slotStart,
    @TimestampConverter() DateTime? slotEnd,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? completedAt,

    String? status,
    String? cancelledBy,              // 'student' | 'teacher'
    @TimestampConverter() DateTime? cancelledAt,
    @Default(false) bool studentNoShow, // teacher reported: student didn't attend
    @Default(false) bool teacherNoShow, // student reported: teacher didn't attend
    double? refundAmount,             // EGP refunded to student on cancellation
    double? refundPercent,            // 0, 50, or 100

    // PAYMENT FIELDS
    @Default(false) bool isPaid,
    String? paymentId,
    String? subscriptionId,
    String? paymentType, // 'bundle' | 'subscription' | 'direct' | null
    double? sessionPrice,

    // ONLINE SESSION FIELDS
    String? preferredProvider, // 'zoom' | 'googleMeet' | 'teams' (chosen by student)
    String? meetingLink,
    String? meetingId,
    String? meetingPassword,
    @Default(false) bool isMeetingLinkSent,
    @TimestampConverter() DateTime? meetingScheduledAt,

    // QURAN MISTAKE TRACKING
    @Default(<QuranMistake>[]) List<QuranMistake> mistakes,
    @Default(<int>[]) List<int> pagesRead,
    int? currentPage,

    @Default(0) int tajweedMistakesCount,
    @Default(0) int pronunciationMistakesCount,
    @Default(0) int readingMistakesCount,
    @Default(0) int skipMistakesCount,
    @Default(0) int additionMistakesCount,
    @Default(0) int otherMistakesCount,
  }) = _SessionModel;

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }
}

// ==================== EXTENSION METHODS ====================
extension SessionModelExtensions on SessionModel {
  /// Get total number of mistakes
  int get totalMistakes => mistakes.length;

  /// Check if session has any mistakes
  bool get hasMistakes => mistakes.isNotEmpty;

  /// Get mistakes grouped by page
  Map<int, List<QuranMistake>> get mistakesByPage {
    return mistakes.fold<Map<int, List<QuranMistake>>>(
      {},
      (map, mistake) {
        map.putIfAbsent(mistake.pageNumber, () => []);
        map[mistake.pageNumber]!.add(mistake);
        return map;
      },
    );
  }

  /// Get mistakes grouped by type
  Map<MistakeType, List<QuranMistake>> get mistakesByType {
    return mistakes.fold<Map<MistakeType, List<QuranMistake>>>(
      {},
      (map, mistake) {
        map.putIfAbsent(mistake.type, () => []);
        map[mistake.type]!.add(mistake);
        return map;
      },
    );
  }

  /// Get mistakes for a specific page
  List<QuranMistake> mistakesForPage(int pageNumber) {
    return mistakes.where((m) => m.pageNumber == pageNumber).toList();
  }

  /// Get mistakes of a specific type
  List<QuranMistake> mistakesOfType(MistakeType type) {
    return mistakes.where((m) => m.type == type).toList();
  }

  /// Calculate mistake statistics
  Map<String, dynamic> get mistakeStatistics {
    return {
      'total': totalMistakes,
      'tajweed': mistakesOfType(MistakeType.tajweed).length,
      'pronunciation': mistakesOfType(MistakeType.pronunciation).length,
      'reading': mistakesOfType(MistakeType.reading).length,
      'skip': mistakesOfType(MistakeType.skip).length,
      'addition': mistakesOfType(MistakeType.addition).length,
      'other': mistakesOfType(MistakeType.other).length,
      'pagesWithMistakes': mistakesByPage.length,
      'averageMistakesPerPage': mistakesByPage.isEmpty
          ? 0.0
          : totalMistakes / mistakesByPage.length,
    };
  }

  /// Get the most common mistake type
  MistakeType? get mostCommonMistakeType {
    if (mistakes.isEmpty) return null;

    final typeGroups = mistakesByType;
    MapEntry<MistakeType, List<QuranMistake>>? maxEntry;

    for (final entry in typeGroups.entries) {
      if (maxEntry == null || entry.value.length > maxEntry.value.length) {
        maxEntry = entry;
      }
    }

    return maxEntry?.key;
  }

  /// Get page range (first to last page read)
  String? get pageRange {
    if (pagesRead.isEmpty) return null;
    final sorted = pagesRead.toList()..sort();
    if (sorted.length == 1) return 'صفحة ${sorted.first}';
    return 'من صفحة ${sorted.first} إلى ${sorted.last}';
  }

  /// Check if session is completed
  bool get isCompleted => status == 'completed' && completedAt != null;

  /// Check if session has been reviewed (has mistakes or notes)
  bool get hasBeenReviewed =>
      hasMistakes ||
      (sessionNotes != null && sessionNotes!.isNotEmpty) ||
      (performanceNotes != null && performanceNotes!.isNotEmpty);
}

