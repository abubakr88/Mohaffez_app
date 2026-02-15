import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_model.dart'; // for TimestampConverter

part 'quran_mistake_model.freezed.dart';
part 'quran_mistake_model.g.dart';

/// MISTAKE TYPE ENUM
enum MistakeType {
  @JsonValue('tajweed') tajweed,
  @JsonValue('pronunciation') pronunciation,
  @JsonValue('reading') reading,
  @JsonValue('skip') skip,
  @JsonValue('addition') addition,
  @JsonValue('other') other,
}

/// QURAN MISTAKE MODEL
@freezed
class QuranMistake with _$QuranMistake {
  const factory QuranMistake({
    required String id,
    required int pageNumber,
    required int surahNumber,
    required int ayahNumber,
    
    // Position on page (relative coordinates 0.0 to 1.0)
    required double xPosition, // 0.0 (left) to 1.0 (right)
    required double yPosition, // 0.0 (top) to 1.0 (bottom)
    
    // Mistake details
    required MistakeType type,
    String? wordText, // The specific word with mistake
    String? correctionNote, // Teacher's correction note
    
    // Metadata
    @TimestampConverter() DateTime? markedAt,
  }) = _QuranMistake;

  factory QuranMistake.fromJson(Map<String, dynamic> json) => 
      _$QuranMistakeFromJson(json);
}

/// HELPER FUNCTIONS
extension MistakeTypeExtensions on MistakeType {
  String get arabicLabel {
    switch (this) {
      case MistakeType.tajweed: return 'تجويد';
      case MistakeType.pronunciation: return 'نطق';
      case MistakeType.reading: return 'قراءة';
      case MistakeType.skip: return 'تخطي';
      case MistakeType.addition: return 'زيادة';
      case MistakeType.other: return 'أخرى';
    }
  }

  String get description {
    switch (this) {
      case MistakeType.tajweed: return 'خطأ في أحكام التجويد';
      case MistakeType.pronunciation: return 'خطأ في النطق';
      case MistakeType.reading: return 'خطأ في القراءة';
      case MistakeType.skip: return 'تخطي كلمة أو آية';
      case MistakeType.addition: return 'إضافة كلمة';
      case MistakeType.other: return 'خطأ آخر';
    }
  }

  String get iconName {
    switch (this) {
      case MistakeType.tajweed: return 'auto_fix_high';
      case MistakeType.pronunciation: return 'record_voice_over';
      case MistakeType.reading: return 'error_outline';
      case MistakeType.skip: return 'fast_forward';
      case MistakeType.addition: return 'add_circle_outline';
      case MistakeType.other: return 'help_outline';
    }
  }
}

extension QuranMistakeExtensions on QuranMistake {
  /// Get display text for mistake location
  String get locationText {
    if (wordText != null && wordText!.isNotEmpty) {
      return 'صفحة $pageNumber - آية $ayahNumber: $wordText';
    }
    return 'صفحة $pageNumber - آية $ayahNumber';
  }

  /// Get time ago text
  String get timeAgo {
    if (markedAt == null) return 'غير محدد';
    final now = DateTime.now();
    final difference = now.difference(markedAt!);
    
    if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }
}
