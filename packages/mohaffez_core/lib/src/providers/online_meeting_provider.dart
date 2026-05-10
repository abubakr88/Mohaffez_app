import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, Timestamp;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeetingInfo {
  final String provider;
  final String roomId;
  final String url;
  final DateTime? joinWindowOpensAt;
  final DateTime? joinWindowClosesAt;
  final DateTime? startedAt;
  final DateTime? studentJoinedAt;
  final DateTime? teacherJoinedAt;

  const MeetingInfo({
    required this.provider,
    required this.roomId,
    required this.url,
    this.joinWindowOpensAt,
    this.joinWindowClosesAt,
    this.startedAt,
    this.studentJoinedAt,
    this.teacherJoinedAt,
  });

  factory MeetingInfo.fromDoc(Map<String, dynamic> doc) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    final meeting = doc['meeting'] as Map<String, dynamic>? ?? const {};
    return MeetingInfo(
      provider: meeting['provider'] as String? ?? 'custom',
      roomId: meeting['roomId'] as String? ?? '',
      url: meeting['url'] as String? ?? '',
      joinWindowOpensAt: ts(meeting['joinWindowOpensAt']),
      joinWindowClosesAt: ts(meeting['joinWindowClosesAt']),
      startedAt: ts(doc['meetingStartedAt']),
      studentJoinedAt: ts(doc['meetingStudentJoinedAt']),
      teacherJoinedAt: ts(doc['meetingTeacherJoinedAt']),
    );
  }
}

enum MeetingButtonState {
  hidden,
  pendingMeetingLink,
  tooEarly,
  ready,
  inProgress,
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
    if (data['meeting'] == null) return null;
    return MeetingInfo.fromDoc(data);
  });
});

final _meetingClockProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final meetingButtonStateProvider =
    Provider.family<MeetingButtonState, String>((ref, sessionId) {
  if (sessionId.isEmpty) return MeetingButtonState.hidden;

  final infoAsync = ref.watch(meetingInfoProvider(sessionId));
  ref.watch(_meetingClockProvider);

  return infoAsync.when(
    data: _computeState,
    loading: () => MeetingButtonState.pendingMeetingLink,
    error: (_, __) => MeetingButtonState.hidden,
  );
});

MeetingButtonState _computeState(MeetingInfo? info) {
  if (info == null || info.url.isEmpty) return MeetingButtonState.pendingMeetingLink;

  // Teacher started, or anyone joined → in progress (overrides window — supports
  // early/late start).
  if (info.startedAt != null ||
      info.studentJoinedAt != null ||
      info.teacherJoinedAt != null) {
    return MeetingButtonState.inProgress;
  }

  final now = DateTime.now();
  final opensAt = info.joinWindowOpensAt;
  final closesAt = info.joinWindowClosesAt;

  if (closesAt != null && now.isAfter(closesAt)) return MeetingButtonState.ended;
  if (opensAt != null && now.isBefore(opensAt)) return MeetingButtonState.tooEarly;

  return MeetingButtonState.ready;
}
