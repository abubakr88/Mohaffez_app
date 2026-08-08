import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, Timestamp;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'system_config_provider.dart';

class MeetingInfo {
  final String provider;
  final String roomId;
  final String url;
  final String preferredProvider;
  final String studentPhone;
  final String mohaffezPhone;

  /// Day-only date (midnight). Use `slotStart` for time-of-day comparisons.
  final DateTime? sessionDate;

  /// Actual session start datetime (includes hour + minute). Preferred over
  /// `sessionDate` for all stale-guard and lead-time calculations.
  final DateTime? slotStart;
  final DateTime? joinWindowOpensAt;
  final DateTime? joinWindowClosesAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? studentJoinedAt;
  final DateTime? teacherJoinedAt;

  /// Root-level session status (`pending`, `accepted`, `completed`, …).
  /// Once `completed`, the meeting button must render the ended state
  /// regardless of meetingEndedAt/sessionTime — see `_computeState`.
  final String status;

  const MeetingInfo({
    required this.provider,
    required this.roomId,
    required this.url,
    this.preferredProvider = '',
    this.studentPhone = '',
    this.mohaffezPhone = '',
    this.sessionDate,
    this.slotStart,
    this.joinWindowOpensAt,
    this.joinWindowClosesAt,
    this.startedAt,
    this.endedAt,
    this.studentJoinedAt,
    this.teacherJoinedAt,
    this.status = '',
  });

  factory MeetingInfo.fromDoc(Map<String, dynamic> doc) {
    // Accept both Timestamp (normal) and DateTime (Firestore auto-conversion).
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final meeting = doc['meeting'] as Map<String, dynamic>? ?? const {};
    final preferredProvider = doc['preferredProvider'] as String? ?? '';
    return MeetingInfo(
      provider: meeting['provider'] as String? ??
          (preferredProvider == 'phoneCall' ? 'phoneCall' : 'custom'),
      roomId: meeting['roomId'] as String? ?? '',
      url: meeting['url'] as String? ?? '',
      preferredProvider: preferredProvider,
      studentPhone: doc['studentPhone'] as String? ?? '',
      mohaffezPhone: doc['mohaffezPhone'] as String? ?? '',
      sessionDate: ts(doc['sessionDate']),
      slotStart: ts(doc['slotStart']),
      joinWindowOpensAt: ts(meeting['joinWindowOpensAt']),
      joinWindowClosesAt: ts(meeting['joinWindowClosesAt']),
      startedAt: ts(doc['meetingStartedAt']),
      endedAt: ts(doc['meetingEndedAt']),
      studentJoinedAt: ts(doc['meetingStudentJoinedAt']),
      teacherJoinedAt: ts(doc['meetingTeacherJoinedAt']),
      status: doc['status'] as String? ?? '',
    );
  }

  bool get isPhoneCall =>
      provider == 'phoneCall' || preferredProvider == 'phoneCall';
}

enum MeetingButtonState {
  hidden,
  pendingMeetingLink,
  tooEarly, // both roles: now < slotStart − leadTimeMinutes
  waitingForTeacher, // student: window open, teacher hasn't started yet
  teacherLate, // student: teacher hasn't started 5+ min after slotStart
  ready, // teacher-only: can click "ابدأ الجلسة"
  inProgress, // teacher started; both roles can interact with the meeting
  ended,
}

final meetingInfoProvider =
    StreamProvider.autoDispose.family<MeetingInfo?, String>((ref, sessionId) {
  final authUid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (authUid == null || sessionId.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('hafizSessions')
      .doc(sessionId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    // Build MeetingInfo whenever there is anything to show — either the
    // meeting{} map exists, the teacher has stamped a root-level activity
    // timestamp (start / join), or the session has reached a terminal
    // status (completed/cancelled). Otherwise return null so the button
    // stays in pendingMeetingLink.
    final status = data['status'] as String? ?? '';
    final isTerminal = status == 'completed' || status == 'cancelled';
    final hasActivity = data['meetingStartedAt'] != null ||
        data['meetingStudentJoinedAt'] != null ||
        data['meetingTeacherJoinedAt'] != null;
    final isPhoneCall = data['preferredProvider'] == 'phoneCall';
    if (data['meeting'] == null &&
        !hasActivity &&
        !isTerminal &&
        !isPhoneCall) {
      return null;
    }
    return MeetingInfo.fromDoc(data);
  });
});

final _meetingClockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

typedef MeetingButtonKey = ({String sessionId, String role});

final meetingButtonStateProvider =
    Provider.autoDispose.family<MeetingButtonState, MeetingButtonKey>(
  (ref, key) {
    if (key.sessionId.isEmpty) return MeetingButtonState.hidden;

    final infoAsync = ref.watch(meetingInfoProvider(key.sessionId));
    ref.watch(_meetingClockProvider);
    final systemConfig = ref.watch(systemConfigProvider).valueOrNull;
    final leadTimeMinutes = systemConfig?.meetingStartLeadTimeMinutes ?? 60;
    // NTP correction disabled — the `ntp` package returns unreliable offsets
    // on some devices. Device clock is used directly.
    // final offset = ref.watch(serverClockProvider).offset ?? Duration.zero;

    return infoAsync.when(
      data: (info) => _computeState(
        info: info,
        role: key.role,
        leadTimeMinutes: leadTimeMinutes,
        now: DateTime.now(),
      ),
      loading: () => MeetingButtonState.pendingMeetingLink,
      error: (_, __) => MeetingButtonState.hidden,
    );
  },
  dependencies: [meetingInfoProvider],
);

MeetingButtonState _computeState({
  required MeetingInfo? info,
  required String role,
  required int leadTimeMinutes,
  required DateTime now,
}) {
  // Terminal session status wins over everything. Once the teacher hits
  // "complete" (or the auto-end CF marks it completed), no role should
  // ever see a join button again.
  if (info != null &&
      (info.status == 'completed' || info.status == 'cancelled')) {
    return MeetingButtonState.ended;
  }

  if (info == null || (!info.isPhoneCall && info.url.isEmpty)) {
    return MeetingButtonState.pendingMeetingLink;
  }

  // `slotStart` is the actual session datetime (hour + minute).
  // `sessionDate` is day-only (midnight) — never use it alone for time math.
  final sessionTime = info.slotStart ?? info.sessionDate;

  // ended: teacher explicitly stamped meetingEndedAt (legacy path — the
  // status check above already catches normal completions).
  if (info.endedAt != null) {
    return MeetingButtonState.ended;
  }

  // Teacher started → both roles see inProgress.
  if (info.startedAt != null) {
    return MeetingButtonState.inProgress;
  }

  if (role == 'mohaffez') {
    if (sessionTime == null) return MeetingButtonState.ready;
    final earliestStart =
        sessionTime.subtract(Duration(minutes: leadTimeMinutes));
    if (now.isBefore(earliestStart)) return MeetingButtonState.tooEarly;
    return MeetingButtonState.ready;
  }

  // Student: same entry gate as teacher — slotStart − leadTimeMinutes.
  if (sessionTime != null) {
    final earliestStart =
        sessionTime.subtract(Duration(minutes: leadTimeMinutes));
    if (now.isBefore(earliestStart)) return MeetingButtonState.tooEarly;

    // Teacher is late: 5 min past session start and still hasn't started.
    final lateThreshold = sessionTime.add(const Duration(minutes: 5));
    if (now.isAfter(lateThreshold)) return MeetingButtonState.teacherLate;
  }

  return MeetingButtonState.waitingForTeacher;
}
