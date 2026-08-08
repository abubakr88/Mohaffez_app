import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../data/recitation_deck.dart';

const liveRecitationGameDocumentId = 'recitationCards';
const liveRecitationSchemaVersion = 1;

enum LiveRecitationStatus { playing, finished, closed }

class LiveRecitationState {
  final String sessionId;
  final String mohaffezId;
  final String studentId;
  final String? studentProfileId;
  final LiveRecitationStatus status;
  final int roundId;
  final int seed;
  final int cardCount;
  final List<RecitationScope> scopes;
  final int? selectedIndex;
  final Map<int, bool> results;

  const LiveRecitationState({
    required this.sessionId,
    required this.mohaffezId,
    required this.studentId,
    required this.studentProfileId,
    required this.status,
    required this.roundId,
    required this.seed,
    required this.cardCount,
    required this.scopes,
    required this.selectedIndex,
    required this.results,
  });

  bool get isFinished => status == LiveRecitationStatus.finished;
  bool get isClosed => status == LiveRecitationStatus.closed;

  static LiveRecitationState? fromMap(
    String sessionId,
    Map<String, dynamic>? data,
  ) {
    if (data == null || data['schemaVersion'] != liveRecitationSchemaVersion) {
      return null;
    }
    final status = switch (data['status']) {
      'playing' => LiveRecitationStatus.playing,
      'finished' => LiveRecitationStatus.finished,
      'closed' => LiveRecitationStatus.closed,
      _ => null,
    };
    if (status == null) return null;

    final cardCount = (data['cardCount'] as num?)?.toInt();
    final roundId = (data['roundId'] as num?)?.toInt();
    final seed = (data['seed'] as num?)?.toInt();
    if (cardCount == null ||
        !const [4, 6, 8].contains(cardCount) ||
        roundId == null ||
        seed == null) {
      return null;
    }

    final scopes = (data['scopes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final map = Map<String, dynamic>.from(raw);
          final surahNumber = (map['surahNumber'] as num?)?.toInt();
          if (surahNumber == null ||
              !QuranService.surahNames.containsKey(surahNumber)) {
            return null;
          }
          return RecitationScope(
            surahNumber: surahNumber,
            surahName: QuranService.surahNames[surahNumber]!,
            fromAyah: (map['fromAyah'] as num?)?.toInt(),
            toAyah: (map['toAyah'] as num?)?.toInt(),
          );
        })
        .whereType<RecitationScope>()
        .toList(growable: false);
    if (scopes.isEmpty) return null;

    final results = <int, bool>{};
    final rawResults = data['results'];
    if (rawResults is Map) {
      for (final entry in rawResults.entries) {
        final index = int.tryParse(entry.key.toString());
        if (index != null &&
            index >= 0 &&
            index < cardCount &&
            entry.value is bool) {
          results[index] = entry.value as bool;
        }
      }
    }

    final rawSelectedIndex = (data['selectedIndex'] as num?)?.toInt();
    final selectedIndex = rawSelectedIndex != null &&
            rawSelectedIndex >= 0 &&
            rawSelectedIndex < cardCount
        ? rawSelectedIndex
        : null;

    return LiveRecitationState(
      sessionId: sessionId,
      mohaffezId: data['mohaffezId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentProfileId: _cleanProfileId(data['studentProfileId']),
      status: status,
      roundId: roundId,
      seed: seed,
      cardCount: cardCount,
      scopes: scopes,
      selectedIndex: selectedIndex,
      results: Map.unmodifiable(results),
    );
  }
}

class LiveRecitationSessionInfo {
  final String sessionId;
  final String mohaffezName;
  final DateTime startedAt;

  const LiveRecitationSessionInfo({
    required this.sessionId,
    required this.mohaffezName,
    required this.startedAt,
  });
}

String? _cleanProfileId(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'self') return null;
  return text;
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// Finds the active session from the stream already used by StudentHome.
/// This deliberately creates no additional Firestore query.
LiveRecitationSessionInfo? activeLiveRecitationSessionFromSessions(
  List<Map<String, dynamic>> sessions, {
  required String studentId,
  required String? studentProfileId,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final expectedProfile = _cleanProfileId(studentProfileId);
  final active = <LiveRecitationSessionInfo>[];

  for (final session in sessions) {
    if (session['status'] != 'accepted' ||
        (session['studentId'] as String? ?? studentId) != studentId ||
        _cleanProfileId(session['studentProfileId']) != expectedProfile ||
        _date(session['meetingEndedAt']) != null) {
      continue;
    }

    final meetingStartedAt = _date(session['meetingStartedAt']);
    final sessionType = session['sessionType'] as String? ?? '';
    if (sessionType == 'online' && meetingStartedAt == null) continue;

    final start = meetingStartedAt ??
        _date(session['slotStart']) ??
        _date(session['sessionDate']);
    if (start == null || current.isBefore(start)) continue;

    final explicitEnd = _date(session['slotEnd']);
    final duration =
        ((session['sessionDurationMinutes'] as num?)?.toInt() ?? 90)
            .clamp(15, 240);
    final end = explicitEnd ?? start.add(Duration(minutes: duration));
    if (current.isAfter(end.add(const Duration(minutes: 15)))) continue;

    final sessionId = session['id'] as String? ?? '';
    if (sessionId.isEmpty) continue;
    active.add(
      LiveRecitationSessionInfo(
        sessionId: sessionId,
        mohaffezName: session['mohaffezName'] as String? ?? '',
        startedAt: start,
      ),
    );
  }

  if (active.isEmpty) return null;
  active.sort((left, right) => right.startedAt.compareTo(left.startedAt));
  return active.first;
}

DocumentReference<Map<String, dynamic>> _liveRecitationRef(
  String sessionId,
) {
  return FirebaseFirestore.instance
      .collection('hafizSessions')
      .doc(sessionId)
      .collection('liveGames')
      .doc(liveRecitationGameDocumentId);
}

final liveRecitationStateProvider = StreamProvider.autoDispose
    .family<LiveRecitationState?, String>((ref, sessionId) {
  return _liveRecitationRef(sessionId).snapshots().map(
        (snapshot) => LiveRecitationState.fromMap(
          sessionId,
          snapshot.data(),
        ),
      );
});

Future<void> startLiveRecitationRound({
  required String sessionId,
  required String mohaffezId,
  required String studentId,
  required String? studentProfileId,
  required List<RecitationScope> scopes,
  required int cardCount,
  required int roundId,
  required int seed,
}) {
  return _liveRecitationRef(sessionId).set(
    liveRecitationRoundPayload(
      mohaffezId: mohaffezId,
      studentId: studentId,
      studentProfileId: studentProfileId,
      scopes: scopes,
      cardCount: cardCount,
      roundId: roundId,
      seed: seed,
    ),
  );
}

/// Builds the intentionally small synchronized payload. Card text, ayah text,
/// page contents, and generated card objects never leave the device.
Map<String, dynamic> liveRecitationRoundPayload({
  required String mohaffezId,
  required String studentId,
  required String? studentProfileId,
  required List<RecitationScope> scopes,
  required int cardCount,
  required int roundId,
  required int seed,
  DateTime? expiresAt,
}) {
  final enabledScopes = scopes.where((scope) => scope.enabled).toList();
  return {
    'schemaVersion': liveRecitationSchemaVersion,
    'mohaffezId': mohaffezId,
    'studentId': studentId,
    'studentProfileId': _cleanProfileId(studentProfileId) ?? 'self',
    'status': 'playing',
    'roundId': roundId,
    'seed': seed,
    'cardCount': cardCount,
    'scopes': [
      for (final scope in enabledScopes)
        {
          'surahNumber': scope.surahNumber,
          if (scope.fromAyah != null) 'fromAyah': scope.fromAyah,
          if (scope.toAyah != null) 'toAyah': scope.toAyah,
        },
    ],
    'selectedIndex': null,
    'selectedBy': null,
    'results': <String, bool>{},
    'startedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'expiresAt': Timestamp.fromDate(
      expiresAt ?? DateTime.now().add(const Duration(hours: 3)),
    ),
  };
}

Future<void> selectLiveRecitationCard({
  required String sessionId,
  required int cardIndex,
  required String actorId,
}) {
  return _liveRecitationRef(sessionId).update({
    'selectedIndex': cardIndex,
    'selectedBy': actorId,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> gradeLiveRecitationCard({
  required String sessionId,
  required int cardIndex,
  required bool mastered,
  required bool finishesRound,
}) {
  return _liveRecitationRef(sessionId).update({
    'results.$cardIndex': mastered,
    'selectedIndex': null,
    'selectedBy': null,
    'status': finishesRound ? 'finished' : 'playing',
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> closeLiveRecitationGame(String sessionId) {
  return _liveRecitationRef(sessionId).update({
    'status': 'closed',
    'selectedIndex': null,
    'selectedBy': null,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
