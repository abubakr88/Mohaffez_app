import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

class TrialSessionPair {
  const TrialSessionPair({
    required this.mohaffezId,
    required this.studentId,
    this.studentProfileId,
  });

  final String mohaffezId;
  final String studentId;
  final String? studentProfileId;

  String get requestId {
    final profileId = studentProfileId?.trim();
    if (profileId == null || profileId.isEmpty || profileId == 'self') {
      return '${mohaffezId}_$studentId';
    }
    return '${mohaffezId}_${studentId}_$profileId';
  }

  @override
  bool operator ==(Object other) =>
      other is TrialSessionPair &&
      other.mohaffezId == mohaffezId &&
      other.studentId == studentId &&
      other.studentProfileId == studentProfileId;

  @override
  int get hashCode => Object.hash(mohaffezId, studentId, studentProfileId);
}

final trialRequestForPairProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>?, TrialSessionPair>(
  (ref, pair) {
    return FirebaseFirestore.instance
        .collection('trialSessionRequests')
        .doc(pair.requestId)
        .snapshots()
        .map((snapshot) => snapshot.exists
            ? <String, dynamic>{
                ...snapshot.data()!,
                'id': snapshot.id,
              }
            : null);
  },
);

final trialSessionRequestsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);

  final field = user.role == 'mohaffez' ? 'mohaffezId' : 'studentId';
  return FirebaseFirestore.instance
      .collection('trialSessionRequests')
      .where(field, isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) {
    final requests = snapshot.docs
        .map((doc) => <String, dynamic>{
              ...doc.data(),
              'id': doc.id,
            })
        .toList();
    requests.sort((left, right) {
      final leftTime = left['createdAt'] is Timestamp
          ? (left['createdAt'] as Timestamp).millisecondsSinceEpoch
          : 0;
      final rightTime = right['createdAt'] is Timestamp
          ? (right['createdAt'] as Timestamp).millisecondsSinceEpoch
          : 0;
      return rightTime.compareTo(leftTime);
    });
    return requests;
  });
}, dependencies: [currentUserProvider]);

final teacherTrialSettingsProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, teacherId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(teacherId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      return {
        'acceptingNewBookings': data['acceptingNewBookings'] != false,
        'enabled': data['trialSessionEnabled'] == true,
        'durationMinutes':
            (data['trialSessionDurationMinutes'] as num?)?.toInt() ?? 30,
      };
    });
  },
);

final trialSessionActionsProvider =
    StateNotifierProvider<TrialSessionActions, AsyncValue<void>>((ref) {
  return TrialSessionActions();
});

class TrialSessionActions extends StateNotifier<AsyncValue<void>> {
  TrialSessionActions() : super(const AsyncValue.data(null));

  Future<void> _call(String name, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseFunctions.instance
          .httpsCallable(
            name,
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 30),
            ),
          )
          .call(data);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> createRequest({
    required String mohaffezId,
    required String sessionType,
    String? preferredProvider,
    required List<Map<String, String>> availabilityWindows,
    required Map<String, dynamic> studentPreparation,
    Map<String, dynamic> learnerSnapshot = const {},
  }) {
    return _call('createTrialSessionRequest', {
      'mohaffezId': mohaffezId,
      'sessionType': sessionType,
      if (sessionType == 'online' && preferredProvider != null)
        'preferredProvider': preferredProvider,
      'availabilityWindows': availabilityWindows,
      'studentPreparation': studentPreparation,
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      ...learnerSnapshot,
    });
  }

  Future<void> proposeTime({
    required String requestId,
    required DateTime proposedStart,
  }) {
    return _call('proposeTrialSessionTime', {
      'requestId': requestId,
      'proposedStart': proposedStart.toUtc().toIso8601String(),
    });
  }

  Future<void> confirmTime(String requestId) {
    return _call('confirmTrialSessionTime', {
      'requestId': requestId,
    });
  }

  Future<void> reject({
    required String requestId,
    required String reason,
  }) {
    return _call('rejectTrialSessionRequest', {
      'requestId': requestId,
      'reason': reason,
    });
  }
}
