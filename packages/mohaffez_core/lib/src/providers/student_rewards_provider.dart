// lib/providers/student_rewards_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Surah names (1-based index) ──────────────────────────────────────────────
const List<String> surahNames = [
  'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة',
  'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
  'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر',
  'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
  'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان',
  'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
  'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر',
  'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
  'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية',
  'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
  'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن',
  'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
  'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق',
  'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
  'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة',
  'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
  'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج',
  'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
  'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين',
  'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
  'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل',
  'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
  'المسد', 'الإخلاص', 'الفلق', 'الناس',
];

// ─── Level system ─────────────────────────────────────────────────────────────
class StudentLevel {
  final String name;
  final String emoji;
  final int currentMin;
  final int nextMin; // -1 = max level
  final int rank; // 0-based

  const StudentLevel({
    required this.name,
    required this.emoji,
    required this.currentMin,
    required this.nextMin,
    required this.rank,
  });

  double progressTo(int sessions) {
    if (nextMin == -1) return 1.0;
    final range = nextMin - currentMin;
    if (range <= 0) return 1.0;
    return ((sessions - currentMin) / range).clamp(0.0, 1.0);
  }

  int sessionsToNext(int sessions) {
    if (nextMin == -1) return 0;
    return (nextMin - sessions).clamp(0, nextMin);
  }
}

List<StudentLevel> _levelsForAge(int age) {
  if (age < 12) {
    return const [
      StudentLevel(name: 'مبتدئ',  emoji: '🌱', currentMin: 0,  nextMin: 3,  rank: 0),
      StudentLevel(name: 'متعلم',  emoji: '📖', currentMin: 3,  nextMin: 9,  rank: 1),
      StudentLevel(name: 'مجتهد', emoji: '⭐', currentMin: 9,  nextMin: 19, rank: 2),
      StudentLevel(name: 'متقن',   emoji: '🌙', currentMin: 19, nextMin: 40, rank: 3),
      StudentLevel(name: 'النابغة', emoji: '👑', currentMin: 40, nextMin: -1, rank: 4),
    ];
  } else if (age < 18) {
    return const [
      StudentLevel(name: 'مبتدئ',   emoji: '🌱', currentMin: 0,  nextMin: 4,  rank: 0),
      StudentLevel(name: 'متعلم',   emoji: '📖', currentMin: 4,  nextMin: 11, rank: 1),
      StudentLevel(name: 'مجتهد',  emoji: '⭐', currentMin: 11, nextMin: 25, rank: 2),
      StudentLevel(name: 'متقن',    emoji: '🌙', currentMin: 25, nextMin: 50, rank: 3),
      StudentLevel(name: 'المتميز', emoji: '🏆', currentMin: 50, nextMin: -1, rank: 4),
    ];
  } else {
    return const [
      StudentLevel(name: 'مبتدئ',  emoji: '🌱', currentMin: 0,  nextMin: 5,  rank: 0),
      StudentLevel(name: 'متعلم',  emoji: '📖', currentMin: 5,  nextMin: 15, rank: 1),
      StudentLevel(name: 'مجتهد', emoji: '⭐', currentMin: 15, nextMin: 30, rank: 2),
      StudentLevel(name: 'متقن',   emoji: '🌙', currentMin: 30, nextMin: 60, rank: 3),
      StudentLevel(name: 'الحافظ', emoji: '🏆', currentMin: 60, nextMin: -1, rank: 4),
    ];
  }
}

int calculateAge(DateTime? dob) {
  if (dob == null) return 20;
  final now = DateTime.now();
  int age = now.year - dob.year;
  if (now.month < dob.month ||
      (now.month == dob.month && now.day < dob.day)) {
    age--;
  }
  return age.clamp(0, 120);
}

StudentLevel resolveLevel(int sessions, int age) {
  final levels = _levelsForAge(age);
  StudentLevel current = levels.first;
  for (final level in levels) {
    if (sessions >= level.currentMin) current = level;
  }
  return current;
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Real-time stream of memorized surah numbers (1-114) for a student.
final memorizedSurahsProvider = StreamProvider.family<List<int>, String>(
  (ref, studentId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(studentId)
        .collection('memorizedSurahs')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => (d.data()['surahNumber'] as num?)?.toInt() ?? 0)
            .where((n) => n >= 1 && n <= 114)
            .toList());
  },
);

/// Count of completed hafiz sessions for a student.
final studentCompletedSessionsProvider =
    FutureProvider.autoDispose.family<int, String>((ref, studentId) async {
  final agg = await FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('studentId', isEqualTo: studentId)
      .where('status', isEqualTo: 'completed')
      .count()
      .get();
  return agg.count ?? 0;
});

// ─── Write helper ─────────────────────────────────────────────────────────────

Future<void> toggleMemorizedSurah({
  required String studentId,
  required int surahNumber,
  required bool isCurrentlyMemorized,
  required String mohaffezId,
  required String mohaffezName,
}) async {
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(studentId)
      .collection('memorizedSurahs')
      .doc('$surahNumber');

  if (isCurrentlyMemorized) {
    await docRef.delete();
  } else {
    await docRef.set({
      'surahNumber': surahNumber,
      'surahName': surahNames[surahNumber - 1],
      'memorizedAt': FieldValue.serverTimestamp(),
      'markedBy': mohaffezId,
      'markedByName': mohaffezName,
    });
  }
}
