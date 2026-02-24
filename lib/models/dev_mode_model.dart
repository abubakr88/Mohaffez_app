import 'package:cloud_firestore/cloud_firestore.dart';

class DevModeModel {
  final bool devModeEnabled;
  final List<String> devModeUsers;
  final bool bypassPayment;
  final bool bypassPromoValidation;
  final bool bypassSlotLock;
  final bool mockNotifications;
  final bool skipAppVersionCheck;
  final bool fakeGpsEnabled;
  final double fakeGpsLat;
  final double fakeGpsLng;
  final bool showDebugOverlay;
  final bool logAllFirestoreWrites;
  final bool slowNetworkSimulation;
  final DateTime? updatedAt;
  final String updatedBy;

  const DevModeModel({
    required this.devModeEnabled,
    required this.devModeUsers,
    required this.bypassPayment,
    required this.bypassPromoValidation,
    required this.bypassSlotLock,
    required this.mockNotifications,
    required this.skipAppVersionCheck,
    required this.fakeGpsEnabled,
    required this.fakeGpsLat,
    required this.fakeGpsLng,
    required this.showDebugOverlay,
    required this.logAllFirestoreWrites,
    required this.slowNetworkSimulation,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory DevModeModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final defaults = DevModeModel.defaults();
    final updatedAt = data['updatedAt'];
    return DevModeModel(
      devModeEnabled:
          data['devModeEnabled'] as bool? ?? defaults.devModeEnabled,
      devModeUsers: (data['devModeUsers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          defaults.devModeUsers,
      bypassPayment: data['bypassPayment'] as bool? ?? defaults.bypassPayment,
      bypassPromoValidation: data['bypassPromoValidation'] as bool? ??
          defaults.bypassPromoValidation,
      bypassSlotLock:
          data['bypassSlotLock'] as bool? ?? defaults.bypassSlotLock,
      mockNotifications:
          data['mockNotifications'] as bool? ?? defaults.mockNotifications,
      skipAppVersionCheck:
          data['skipAppVersionCheck'] as bool? ?? defaults.skipAppVersionCheck,
      fakeGpsEnabled:
          data['fakeGpsEnabled'] as bool? ?? defaults.fakeGpsEnabled,
      fakeGpsLat:
          (data['fakeGpsLat'] as num?)?.toDouble() ?? defaults.fakeGpsLat,
      fakeGpsLng:
          (data['fakeGpsLng'] as num?)?.toDouble() ?? defaults.fakeGpsLng,
      showDebugOverlay:
          data['showDebugOverlay'] as bool? ?? defaults.showDebugOverlay,
      logAllFirestoreWrites: data['logAllFirestoreWrites'] as bool? ??
          defaults.logAllFirestoreWrites,
      slowNetworkSimulation: data['slowNetworkSimulation'] as bool? ??
          defaults.slowNetworkSimulation,
      updatedAt:
          updatedAt is Timestamp ? updatedAt.toDate() : defaults.updatedAt,
      updatedBy: data['updatedBy'] as String? ?? defaults.updatedBy,
    );
  }

  factory DevModeModel.defaults() {
    return const DevModeModel(
      devModeEnabled: false,
      devModeUsers: [],
      bypassPayment: false,
      bypassPromoValidation: false,
      bypassSlotLock: false,
      mockNotifications: false,
      skipAppVersionCheck: false,
      fakeGpsEnabled: false,
      fakeGpsLat: 30.0444,
      fakeGpsLng: 31.2357,
      showDebugOverlay: false,
      logAllFirestoreWrites: false,
      slowNetworkSimulation: false,
      updatedAt: null,
      updatedBy: '',
    );
  }

  bool isDevUser(String uid) => devModeEnabled && devModeUsers.contains(uid);

  Map<String, dynamic> toMap() {
    return {
      'devModeEnabled': devModeEnabled,
      'devModeUsers': devModeUsers,
      'bypassPayment': bypassPayment,
      'bypassPromoValidation': bypassPromoValidation,
      'bypassSlotLock': bypassSlotLock,
      'mockNotifications': mockNotifications,
      'skipAppVersionCheck': skipAppVersionCheck,
      'fakeGpsEnabled': fakeGpsEnabled,
      'fakeGpsLat': fakeGpsLat,
      'fakeGpsLng': fakeGpsLng,
      'showDebugOverlay': showDebugOverlay,
      'logAllFirestoreWrites': logAllFirestoreWrites,
      'slowNetworkSimulation': slowNetworkSimulation,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updatedBy': updatedBy,
    };
  }
}
