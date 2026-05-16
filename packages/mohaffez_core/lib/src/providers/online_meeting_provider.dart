import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, Timestamp;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'system_config_provider.dart';

class MeetingInfo {
  final String provider;
  final String roomId;
  final String url;
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

  const MeetingInfo({
    required this.provider,
    required this.roomId,
    required this.url,
    this.sessionDate,
    this.slotStart,
    this.joinWindowOpensAt,
    this.joinWindowClosesAt,
    this.startedAt,
    this.endedAt,
    this.studentJoinedAt,
    this.teacherJoinedAt,
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
    return MeetingInfo(
      provider: meeting['provider'] as String? ?? 'custom',
      roomId: meeting['roomId'] as String? ?? '',
      url: meeting['url'] as String? ?? '',
      sessionDate: ts(doc['sessionDate']),
      slotStart: ts(doc['slotStart']),
      joinWindowOpensAt: ts(meeting['joinWindowOpensAt']),
      joinWindowClosesAt: ts(meeting['joinWindowClosesAt']),
      startedAt: ts(doc['meetingStartedAt']),
      endedAt: ts(doc['meetingEndedAt']),
      studentJoinedAt: ts(doc['meetingStudentJoinedAt']),
      teacherJoinedAt: ts(doc['meetingTeacherJoinedAt']),
    );
  }
}

enum MeetingButtonState {
  hidden,
  pendingMeetingLink,
  tooEarly,           // both roles: now < slotStart − leadTimeMinutes
  waitingForTeacher,  // student: window open, teacher hasn't started yet
  teacherLate,        // student: teacher hasn't started 5+ min after slotStart
  ready,              // teacher-only: can click "ابدأ الجلسة"
  inProgress,         // teacher started; both roles can interact with the meeting
  ended,
}

final meetingInfoProvider =
    StreamProvider.family<MeetingInfo?, String>((ref, sessionId) {
  if (sessionId.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('hafizSessions')
      .doc(sessionId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    // Build MeetingInfo whenever there is anything to show — either the
    // meeting{} map exists or the teacher has stamped a root-level activity
    // timestamp (start / join). Otherwise return null so the button stays
    // in pendingMeetingLink.
    final hasActivity = data['meetingStartedAt'] != null ||
        data['meetingStudentJoinedAt'] != null ||
        data['meetingTeacherJoinedAt'] != null;
    if (data['meeting'] == null && !hasActivity) return null;
    return MeetingInfo.fromDoc(data);
  });
});

final _meetingClockProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

typedef MeetingButtonKey = ({String sessionId, String role});

final meetingButtonStateProvider =
    Provider.family<MeetingButtonState, MeetingButtonKey>(
  (ref, key) {
    if (key.sessionId.isEmpty) return MeetingButtonState.hidden;

    final infoAsync = ref.watch(meetingInfoProvider(key.sessionId));
    ref.watch(_meetingClockProvider);
    final systemConfig = ref.watch(systemConfigProvider).valueOrNull;
    final leadTimeMinutes = systemConfig?.meetingStartLeadTimeMinutes ?? 60;
  print('DEBUG CONFIG: systemConfig: $systemConfig, leadTimeMinutes: $leadTimeMinutes');
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
  if (info == null || info.url.isEmpty) {
    return MeetingButtonState.pendingMeetingLink;
  }

  // `slotStart` is the actual session datetime (hour + minute).
  // `sessionDate` is day-only (midnight) — never use it alone for time math.
  final sessionTime = info.slotStart ?? info.sessionDate;

  // ended: ONLY when the teacher explicitly ends the session (meetingEndedAt).
  // Stale-guard: ignore if we're still before the session's start time.
  if (info.endedAt != null) {
    if (sessionTime == null || !now.isBefore(sessionTime)) {
      return MeetingButtonState.ended;
    }
    // else: stale endedAt — fall through.
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
