import 'package:mohaffez_core/mohaffez_core.dart';

class DemoStudentFixture {
  final UserModel user;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> upcomingSessions;
  final List<Map<String, dynamic>> sampleMohaffezeen;
  final int completedSessionsCount;

  DemoStudentFixture({
    required this.user,
    required this.requests,
    required this.upcomingSessions,
    required this.sampleMohaffezeen,
    required this.completedSessionsCount,
  });
}

class DemoTeacherFixture {
  final UserModel user;
  final List<Map<String, dynamic>> pendingRequests;
  final List<Map<String, dynamic>> upcomingSessions;
  final int pendingRequestsCount;

  DemoTeacherFixture({
    required this.user,
    required this.pendingRequests,
    required this.upcomingSessions,
    required this.pendingRequestsCount,
  });
}

/// Fixtures are built programmatically so date fields can be real `DateTime`
/// objects relative to "now" — no asset bundle, no JSON parsing.
class TourFixtures {
  static DemoStudentFixture? _student;
  static DemoTeacherFixture? _teacher;

  static Future<DemoStudentFixture> loadStudent() async {
    return _student ??= _buildStudent();
  }

  static Future<DemoTeacherFixture> loadTeacher() async {
    return _teacher ??= _buildTeacher();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Student fixture
  // ──────────────────────────────────────────────────────────────────────

  static DemoStudentFixture _buildStudent() {
    final now = DateTime.now();
    final tomorrowMorning =
        DateTime(now.year, now.month, now.day + 1, 9, 0);
    final inThreeDays =
        DateTime(now.year, now.month, now.day + 3, 17, 30);
    final inOneWeek =
        DateTime(now.year, now.month, now.day + 7, 11, 0);

    return DemoStudentFixture(
      user: const UserModel(
        uid: 'tour-student-1',
        name: 'زائر تجريبي',
        email: 'tour-student@mohafezy.demo',
        role: 'student',
        status: 'active',
        phoneNumber: '+201000000000',
        city: 'القاهرة',
        addressText: 'القاهرة، مصر',
        setupCompleted: true,
      ),
      requests: [
        {
          'id': 'demo-req-1',
          'mohaffezId': 'demo-teacher-a',
          'mohaffezName': 'الشيخ محمد عبدالله',
          'studentId': 'tour-student-1',
          'status': 'pending',
          'sessionDate': tomorrowMorning,
          'slotStart': tomorrowMorning,
          'preferredTimeSlot': '09:00',
          'sessionType': 'in_person',
          'createdAt': now.subtract(const Duration(hours: 2)),
        },
        {
          'id': 'demo-req-2',
          'mohaffezId': 'demo-teacher-b',
          'mohaffezName': 'الشيخ أحمد السيد',
          'studentId': 'tour-student-1',
          'status': 'awaitingpayment',
          'sessionDate': inThreeDays,
          'slotStart': inThreeDays,
          'preferredTimeSlot': '17:30',
          'sessionType': 'online',
          'amount': 150,
          'createdAt': now.subtract(const Duration(days: 1)),
        },
      ],
      upcomingSessions: [
        {
          'id': 'demo-sess-1',
          'mohaffezId': 'demo-teacher-a',
          'mohaffezName': 'الشيخ محمد عبدالله',
          'studentId': 'tour-student-1',
          'studentName': 'زائر تجريبي',
          'status': 'accepted',
          'sessionDate': tomorrowMorning,
          'slotStart': tomorrowMorning,
          'preferredTimeSlot': '09:00',
          'sessionType': 'in_person',
          'hifzAssignment': 'سورة الملك من الآية 1 إلى 15',
          'murajaAssignment': 'سورة البقرة من الآية 100 إلى 130',
        },
        {
          'id': 'demo-sess-2',
          'mohaffezId': 'demo-teacher-b',
          'mohaffezName': 'الشيخ أحمد السيد',
          'studentId': 'tour-student-1',
          'studentName': 'زائر تجريبي',
          'status': 'accepted',
          'sessionDate': inOneWeek,
          'slotStart': inOneWeek,
          'preferredTimeSlot': '11:00',
          'sessionType': 'online',
          'hifzAssignment': 'سورة الواقعة كاملة',
          'murajaAssignment': 'جزء عمّ',
        },
      ],
      sampleMohaffezeen: [],
      completedSessionsCount: 12,
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Teacher fixture
  // ──────────────────────────────────────────────────────────────────────

  static DemoTeacherFixture _buildTeacher() {
    final now = DateTime.now();
    final today4pm = DateTime(now.year, now.month, now.day, 16, 0);
    final tomorrow8am =
        DateTime(now.year, now.month, now.day + 1, 8, 0);
    final tomorrow6pm =
        DateTime(now.year, now.month, now.day + 1, 18, 0);
    final inTwoDays =
        DateTime(now.year, now.month, now.day + 2, 10, 30);

    return DemoTeacherFixture(
      user: const UserModel(
        uid: 'tour-teacher-1',
        name: 'الشيخ التجريبي',
        email: 'tour-teacher@mohafezy.demo',
        role: 'mohaffez',
        status: 'active',
        phoneNumber: '+201000000001',
        city: 'القاهرة',
        addressText: 'القاهرة، مصر',
        specialization: 'حفظ ومراجعة وتجويد',
        bio: 'حساب تجريبي لاستعراض إمكانيات التطبيق للمحفظ.',
        setupCompleted: true,
        examPassed: true,
        rating: 4.7,
        reviewCount: 42,
      ),
      pendingRequests: [
        {
          'id': 'demo-pr-1',
          'mohaffezId': 'tour-teacher-1',
          'studentId': 'demo-student-x',
          'studentName': 'عبدالرحمن إبراهيم',
          'status': 'pending',
          'sessionDate': tomorrow8am,
          'slotStart': tomorrow8am,
          'preferredTimeSlot': '08:00',
          'sessionType': 'in_person',
          'createdAt': now.subtract(const Duration(hours: 1)),
        },
        {
          'id': 'demo-pr-2',
          'mohaffezId': 'tour-teacher-1',
          'studentId': 'demo-student-y',
          'studentName': 'يوسف الخطيب',
          'status': 'pending',
          'sessionDate': inTwoDays,
          'slotStart': inTwoDays,
          'preferredTimeSlot': '10:30',
          'sessionType': 'online',
          'createdAt': now.subtract(const Duration(minutes: 30)),
        },
      ],
      upcomingSessions: [
        {
          'id': 'demo-tsess-1',
          'mohaffezId': 'tour-teacher-1',
          'mohaffezName': 'الشيخ التجريبي',
          'studentId': 'demo-student-1',
          'studentName': 'محمد طارق',
          'status': 'accepted',
          'sessionDate': today4pm,
          'slotStart': today4pm,
          'preferredTimeSlot': '16:00',
          'sessionType': 'in_person',
          'hifzAssignment': 'سورة يس من الآية 1 إلى 30',
          'murajaAssignment': 'سورة الكهف من الآية 1 إلى 50',
        },
        {
          'id': 'demo-tsess-2',
          'mohaffezId': 'tour-teacher-1',
          'mohaffezName': 'الشيخ التجريبي',
          'studentId': 'demo-student-2',
          'studentName': 'فاطمة أحمد',
          'status': 'accepted',
          'sessionDate': tomorrow6pm,
          'slotStart': tomorrow6pm,
          'preferredTimeSlot': '18:00',
          'sessionType': 'online',
          'hifzAssignment': 'سورة الرحمن كاملة',
          'murajaAssignment': 'سورة النبأ والنازعات',
        },
      ],
      pendingRequestsCount: 2,
    );
  }
}
