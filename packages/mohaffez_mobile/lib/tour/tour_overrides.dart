import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../providers/mohaffez_profile_providers.dart';
import '../providers/quiz_access_provider.dart';
import '../providers/student_count_provider.dart';
import '../screens/teacher/mohaffez_commission_screen.dart';
import '../screens/teacher/mohaffez_student_detail_screen.dart';
import 'tour_fixtures.dart';
import 'tour_mode_state.dart';

/// Builds the list of provider overrides used while the user is in tour mode.
///
/// Only the *root* providers (currentUserProvider, isUserSuspendedProvider,
/// and the screen-feeding family providers) need explicit overrides. All
/// derivatives that watch currentUserProvider declare it via `dependencies:`
/// so Riverpod recomputes them inside the tour scope automatically.
List<Override> buildTourOverrides(TourRole role, Object fixture) {
  switch (role) {
    case TourRole.student:
      return _studentOverrides(fixture as DemoStudentFixture);
    case TourRole.mohaffez:
      return _teacherOverrides(fixture as DemoTeacherFixture);
  }
}

List<Override> _commonOverrides(UserModel user) {
  final ownerType = user.role == 'mohaffez'
      ? WalletOwnerType.mohaffez
      : WalletOwnerType.student;
  return [
    currentUserProvider.overrideWith((ref) => Stream.value(user)),
    isUserSuspendedProvider.overrideWith((ref) => Stream.value(false)),
    unreadNotificationsCountProvider
        .overrideWith((ref, _) => Stream.value(0)),
    // Wallet system — synthetic UIDs have no real wallet docs in Firestore.
    // Provide an empty wallet + empty ledger so tour-mode users can navigate
    // to the wallet screen without triggering PERMISSION_DENIED.
    walletProvider.overrideWith(
      (ref, _) => Stream.value(WalletModel.empty(user.uid, ownerType)),
    ),
    walletTransactionsProvider
        .overrideWith((ref, _) => Stream.value(const [])),
    payoutRequestsProvider
        .overrideWith((ref, _) => Stream.value(const [])),
  ];
}

final _demoMohaffezList = [
  MohaffezModel(
    id: 'demo-mohaffez-1',
    name: 'أحمد محمد علي',
    specialization: 'حفظ القرآن الكريم',
    addressText: 'القاهرة، مصر الجديدة',
    addressLat: 30.0626,
    addressLng: 31.3397,
    rating: 4.8,
    followerCount: 120,
    bio: 'محفظ معتمد بخبرة 10 سنوات في تعليم القرآن الكريم لجميع الأعمار',
  ),
  MohaffezModel(
    id: 'demo-mohaffez-2',
    name: 'عبد الرحمن يوسف',
    specialization: 'التجويد والحفظ',
    addressText: 'الجيزة، الدقي',
    addressLat: 30.0444,
    addressLng: 31.2086,
    rating: 4.6,
    followerCount: 85,
    bio: 'متخصص في التجويد والحفظ للأطفال والكبار',
  ),
  MohaffezModel(
    id: 'demo-mohaffez-3',
    name: 'محمد إبراهيم حسن',
    specialization: 'حفظ القرآن الكريم',
    addressText: 'الإسكندرية، المنتزه',
    addressLat: 31.2156,
    addressLng: 29.9553,
    rating: 4.9,
    followerCount: 200,
    bio: 'حاصل على إجازة في رواية حفص، خبرة 15 سنة',
  ),
];

List<Override> _studentOverrides(DemoStudentFixture fixture) {
  final now = DateTime.now();
  final pastSessions = <Map<String, dynamic>>[
    {
      'id': 'demo-sess-past-1',
      'mohaffezId': 'demo-teacher-a',
      'mohaffezName': 'الشيخ محمد عبدالله',
      'studentId': 'tour-student-1',
      'studentName': 'زائر تجريبي',
      'status': 'completed',
      'sessionDate': DateTime(now.year, now.month, now.day - 3, 10, 0),
      'slotStart': DateTime(now.year, now.month, now.day - 3, 10, 0),
      'preferredTimeSlot': '10:00',
      'sessionType': 'in_person',
      'hifzAssignment': 'سورة الكهف من الآية 1 إلى 20',
      'murajaAssignment': 'جزء تبارك',
      'teacherRating': 5,
    },
    {
      'id': 'demo-sess-past-2',
      'mohaffezId': 'demo-teacher-b',
      'mohaffezName': 'الشيخ أحمد السيد',
      'studentId': 'tour-student-1',
      'studentName': 'زائر تجريبي',
      'status': 'completed',
      'sessionDate': DateTime(now.year, now.month, now.day - 7, 16, 0),
      'slotStart': DateTime(now.year, now.month, now.day - 7, 16, 0),
      'preferredTimeSlot': '16:00',
      'sessionType': 'online',
      'hifzAssignment': 'سورة الملك كاملة',
      'murajaAssignment': 'سورة الرحمن',
      'teacherRating': 4,
    },
  ];

  return [
    ..._commonOverrides(fixture.user),
    studentRequestsFirstPageProvider
        .overrideWith((ref, _) => Stream.value(fixture.requests)),
    studentUpcomingSessionsProvider
        .overrideWith((ref, _) => Stream.value(fixture.upcomingSessions)),
    studentSessionsFirstPageProvider
        .overrideWith((ref, _) => Stream.value([...fixture.upcomingSessions, ...pastSessions])),
    activeSubscriptionsProvider
        .overrideWith((ref, _) => Stream.value(const <SubscriptionModel>[])),
    allStudentSubscriptionsProvider
        .overrideWith((ref, _) => Stream.value(const <SubscriptionModel>[])),
    filteredSubscriptionsProvider
        .overrideWith((ref, _) => Stream.value(const <SubscriptionModel>[])),
    activeSubscriptionCountProvider
        .overrideWith((ref, _) => Stream.value(0)),
    activeBundleForTeacherProvider
        .overrideWith((ref, _) async => null),
    studentCompletedSessionsProvider
        .overrideWith((ref, _) async => fixture.completedSessionsCount),
    quizUnlockedSessionProvider
        .overrideWith((ref, _) => Stream.value(null)),
    nearbyMohaffezProvider
        .overrideWith((ref, _) async => _demoMohaffezList),
    mohaffezProfileProvider.overrideWith((ref, mohaffezId) async {
      final demo = _demoMohaffezList.firstWhere(
        (m) => m.id == mohaffezId,
        orElse: () => _demoMohaffezList.first,
      );
      return {
        'uid': demo.id,
        'name': demo.name,
        'specialization': demo.specialization ?? '',
        'bio': demo.bio ?? '',
        'rating': demo.rating,
        'followerCount': demo.followerCount,
        'addressText': demo.addressText ?? '',
        'reviewCount': 12,
        'photoUrl': null,
        'youtubeVideoUrl': null,
        'role': 'mohaffez',
      };
    }),
    followStatusProvider.overrideWith((ref, _) => Stream.value(false)),
    credentialsProvider.overrideWith((ref, _) => Stream.value(const [])),
    availabilityProvider.overrideWith((ref, _) => Stream.value(const [])),
    mohaffezStatsProvider.overrideWith(
        (ref, _) => Stream.value({'completedSessions': 45, 'uniqueStudents': 18})),
    mohaffezStudentCountProvider.overrideWith((ref, _) async => 18),
  ];
}

const _demoStudentSummaries = [
  MohaffezStudentSummary(
    studentId: 'demo-student-1',
    studentName: 'محمد طارق',
    sessionCount: 4,
    lastSessionStatus: 'accepted',
    hifzAssignment: 'سورة يس من الآية 1 إلى 30',
    murajaAssignment: 'سورة الكهف من الآية 1 إلى 50',
  ),
  MohaffezStudentSummary(
    studentId: 'demo-student-2',
    studentName: 'فاطمة أحمد',
    sessionCount: 6,
    lastSessionStatus: 'accepted',
    hifzAssignment: 'سورة الرحمن كاملة',
    murajaAssignment: 'سورة النبأ والنازعات',
  ),
];

List<Override> _teacherOverrides(DemoTeacherFixture fixture) {
  return [
    ..._commonOverrides(fixture.user),
    upcomingSessionsProvider
        .overrideWith((ref, _) => Stream.value(fixture.upcomingSessions)),
    pendingRequestsCountProvider
        .overrideWith((ref, _) => fixture.pendingRequestsCount),
    pendingRequestsFirstPageProvider
        .overrideWith((ref, _) => Stream.value(fixture.pendingRequests)),
    mohaffezStudentsProvider
        .overrideWith((ref, _) async => _demoStudentSummaries),
    weeklyCommissionsProvider
        .overrideWith((ref, _) => Stream.value(const [])),
    // Teacher viewing their own profile page
    mohaffezProfileProvider.overrideWith((ref, _) async => {
      'uid': fixture.user.uid,
      'name': fixture.user.name,
      'specialization': fixture.user.specialization ?? 'حفظ ومراجعة وتجويد',
      'bio': fixture.user.bio ?? '',
      'rating': fixture.user.rating,
      'followerCount': 0,
      'addressText': fixture.user.addressText ?? '',
      'reviewCount': fixture.user.reviewCount,
      'photoUrl': null,
      'youtubeVideoUrl': null,
      'role': 'mohaffez',
    }),
    credentialsProvider.overrideWith((ref, _) => Stream.value(const [])),
    availabilityProvider.overrideWith((ref, _) => Stream.value(const [])),
    mohaffezStatsProvider.overrideWith(
        (ref, _) => Stream.value({'completedSessions': 45, 'uniqueStudents': 18})),
    pricingPlansProvider.overrideWith((ref, _) => Stream.value(const [])),
    activePricingPlansProvider.overrideWith((ref, _) => Stream.value(const [])),
    meetingInfoProvider.overrideWith((ref, _) => Stream.value(null)),
    studentDetailSessionsProvider.overrideWith((ref, p) async {
      final now = DateTime.now();
      final summary = _demoStudentSummaries.firstWhere(
        (s) => s.studentId == p.studentId,
        orElse: () => _demoStudentSummaries.first,
      );
      return [
        {
          'id': 'demo-detail-${p.studentId}-1',
          'mohaffezId': p.mohaffezId,
          'studentId': p.studentId,
          'studentName': summary.studentName,
          'status': 'completed',
          'sessionDate': DateTime(now.year, now.month, now.day - 5, 10, 0),
          'slotStart': DateTime(now.year, now.month, now.day - 5, 10, 0),
          'sessionType': 'in_person',
          'hifzAssignment': summary.hifzAssignment,
          'murajaAssignment': summary.murajaAssignment,
          'teacherRating': 5,
        },
        {
          'id': 'demo-detail-${p.studentId}-2',
          'mohaffezId': p.mohaffezId,
          'studentId': p.studentId,
          'studentName': summary.studentName,
          'status': 'completed',
          'sessionDate': DateTime(now.year, now.month, now.day - 12, 16, 0),
          'slotStart': DateTime(now.year, now.month, now.day - 12, 16, 0),
          'sessionType': 'online',
          'hifzAssignment': 'سورة الملك من الآية 1 إلى 15',
          'murajaAssignment': 'جزء عمّ',
          'teacherRating': 4,
        },
        {
          'id': 'demo-detail-${p.studentId}-3',
          'mohaffezId': p.mohaffezId,
          'studentId': p.studentId,
          'studentName': summary.studentName,
          'status': 'accepted',
          'sessionDate': DateTime(now.year, now.month, now.day + 2, 11, 0),
          'slotStart': DateTime(now.year, now.month, now.day + 2, 11, 0),
          'sessionType': 'in_person',
          'hifzAssignment': summary.hifzAssignment,
          'murajaAssignment': summary.murajaAssignment,
        },
      ];
    }),
  ];
}
