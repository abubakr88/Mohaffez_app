import 'package:cloud_firestore/cloud_firestore.dart';

class SystemConfigModel {
  final double commissionRate;
  final double directPaymentCommission;
  final double minimumWithdrawAmount;
  final int paymentDeadlineHours;
  final int promoCodeMaxDiscount;
  final bool freeSessionEnabled;
  final int maxActiveSubscriptions;
  final int slotLockDurationMinutes;
  final int maxPendingRequestsPerStudent;
  final int sessionReminderHours1;
  final int sessionReminderHours2;
  final int maxAdvanceBookingDays;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final List<String> maintenanceAllowedUids;
  final String forceUpdateVersion;
  final String recommendedUpdateVersion;
  final int maxImageUploadSizeMB;
  final int defaultSearchRadiusKm;
  final int maxSearchRadiusKm;
  final bool enableOnlineSessions;
  final bool enableMosqueSessions;
  final bool enableHomeSessions;
  final bool fcmEnabled;
  final bool paymentReminderEnabled;
  final bool sessionReminderEnabled;
  final bool commissionJobEnabled;
  final bool credentialReviewRequired;
  final bool autoApproveMohaffez;
  final bool allowUnverifiedBooking;
  final int maxCredentialFiles;
  final DateTime? updatedAt;
  final String updatedBy;
  final Map<String, String?> adminWallets;

  const SystemConfigModel({
    required this.commissionRate,
    required this.directPaymentCommission,
    required this.minimumWithdrawAmount,
    required this.paymentDeadlineHours,
    required this.promoCodeMaxDiscount,
    required this.freeSessionEnabled,
    required this.maxActiveSubscriptions,
    required this.slotLockDurationMinutes,
    required this.maxPendingRequestsPerStudent,
    required this.sessionReminderHours1,
    required this.sessionReminderHours2,
    required this.maxAdvanceBookingDays,
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.maintenanceAllowedUids,
    required this.forceUpdateVersion,
    required this.recommendedUpdateVersion,
    required this.maxImageUploadSizeMB,
    required this.defaultSearchRadiusKm,
    required this.maxSearchRadiusKm,
    required this.enableOnlineSessions,
    required this.enableMosqueSessions,
    required this.enableHomeSessions,
    required this.fcmEnabled,
    required this.paymentReminderEnabled,
    required this.sessionReminderEnabled,
    required this.commissionJobEnabled,
    required this.credentialReviewRequired,
    required this.autoApproveMohaffez,
    required this.allowUnverifiedBooking,
    required this.maxCredentialFiles,
    required this.updatedAt,
    required this.updatedBy,
    required this.adminWallets,
  });

  factory SystemConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final defaults = SystemConfigModel.defaults();
    final updatedAt = data['updatedAt'];
    return SystemConfigModel(
      commissionRate: (data['commissionRate'] as num?)?.toDouble() ??
          defaults.commissionRate,
      directPaymentCommission:
          (data['directPaymentCommission'] as num?)?.toDouble() ??
              defaults.directPaymentCommission,
      minimumWithdrawAmount:
          (data['minimumWithdrawAmount'] as num?)?.toDouble() ??
              defaults.minimumWithdrawAmount,
      paymentDeadlineHours: (data['paymentDeadlineHours'] as num?)?.toInt() ??
          defaults.paymentDeadlineHours,
      promoCodeMaxDiscount: (data['promoCodeMaxDiscount'] as num?)?.toInt() ??
          defaults.promoCodeMaxDiscount,
      freeSessionEnabled:
          data['freeSessionEnabled'] as bool? ?? defaults.freeSessionEnabled,
      maxActiveSubscriptions:
          (data['maxActiveSubscriptions'] as num?)?.toInt() ??
              defaults.maxActiveSubscriptions,
      slotLockDurationMinutes:
          (data['slotLockDurationMinutes'] as num?)?.toInt() ??
              defaults.slotLockDurationMinutes,
      maxPendingRequestsPerStudent:
          (data['maxPendingRequestsPerStudent'] as num?)?.toInt() ??
              defaults.maxPendingRequestsPerStudent,
      sessionReminderHours1: (data['sessionReminderHours1'] as num?)?.toInt() ??
          defaults.sessionReminderHours1,
      sessionReminderHours2: (data['sessionReminderHours2'] as num?)?.toInt() ??
          defaults.sessionReminderHours2,
      maxAdvanceBookingDays: (data['maxAdvanceBookingDays'] as num?)?.toInt() ??
          defaults.maxAdvanceBookingDays,
      maintenanceMode:
          data['maintenanceMode'] as bool? ?? defaults.maintenanceMode,
      maintenanceMessage:
          data['maintenanceMessage'] as String? ?? defaults.maintenanceMessage,
      maintenanceAllowedUids: (data['maintenanceAllowedUids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          defaults.maintenanceAllowedUids,
      forceUpdateVersion:
          data['forceUpdateVersion'] as String? ?? defaults.forceUpdateVersion,
      recommendedUpdateVersion: data['recommendedUpdateVersion'] as String? ??
          defaults.recommendedUpdateVersion,
      maxImageUploadSizeMB: (data['maxImageUploadSizeMB'] as num?)?.toInt() ??
          defaults.maxImageUploadSizeMB,
      defaultSearchRadiusKm: (data['defaultSearchRadiusKm'] as num?)?.toInt() ??
          defaults.defaultSearchRadiusKm,
      maxSearchRadiusKm: (data['maxSearchRadiusKm'] as num?)?.toInt() ??
          defaults.maxSearchRadiusKm,
      enableOnlineSessions: data['enableOnlineSessions'] as bool? ??
          defaults.enableOnlineSessions,
      enableMosqueSessions: data['enableMosqueSessions'] as bool? ??
          defaults.enableMosqueSessions,
      enableHomeSessions:
          data['enableHomeSessions'] as bool? ?? defaults.enableHomeSessions,
      fcmEnabled: data['fcmEnabled'] as bool? ?? defaults.fcmEnabled,
      paymentReminderEnabled: data['paymentReminderEnabled'] as bool? ??
          defaults.paymentReminderEnabled,
      sessionReminderEnabled: data['sessionReminderEnabled'] as bool? ??
          defaults.sessionReminderEnabled,
      commissionJobEnabled: data['commissionJobEnabled'] as bool? ??
          defaults.commissionJobEnabled,
      credentialReviewRequired: data['credentialReviewRequired'] as bool? ??
          defaults.credentialReviewRequired,
      autoApproveMohaffez:
          data['autoApproveMohaffez'] as bool? ?? defaults.autoApproveMohaffez,
      allowUnverifiedBooking: data['allowUnverifiedBooking'] as bool? ??
          defaults.allowUnverifiedBooking,
      maxCredentialFiles: (data['maxCredentialFiles'] as num?)?.toInt() ??
          defaults.maxCredentialFiles,
      updatedAt:
          updatedAt is Timestamp ? updatedAt.toDate() : defaults.updatedAt,
      updatedBy: data['updatedBy'] as String? ?? defaults.updatedBy,
      adminWallets: Map<String, String?>.from(
        (data['adminWallets'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as String?)),
      ),
    );
  }

  factory SystemConfigModel.defaults() {
    return SystemConfigModel(
      commissionRate: 0.05,
      directPaymentCommission: 0.05,
      minimumWithdrawAmount: 100.0,
      paymentDeadlineHours: 48,
      promoCodeMaxDiscount: 100,
      freeSessionEnabled: true,
      maxActiveSubscriptions: 3,
      slotLockDurationMinutes: 120,
      maxPendingRequestsPerStudent: 5,
      sessionReminderHours1: 24,
      sessionReminderHours2: 1,
      maxAdvanceBookingDays: 30,
      maintenanceMode: false,
      maintenanceMessage: '',
      maintenanceAllowedUids: const [],
      forceUpdateVersion: '1.0.0',
      recommendedUpdateVersion: '1.0.0',
      maxImageUploadSizeMB: 5,
      defaultSearchRadiusKm: 50,
      maxSearchRadiusKm: 150,
      enableOnlineSessions: true,
      enableMosqueSessions: true,
      enableHomeSessions: true,
      fcmEnabled: true,
      paymentReminderEnabled: true,
      sessionReminderEnabled: true,
      commissionJobEnabled: true,
      credentialReviewRequired: true,
      autoApproveMohaffez: false,
      allowUnverifiedBooking: false,
      maxCredentialFiles: 5,
      updatedAt: null,
      updatedBy: '',
      adminWallets: const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commissionRate': commissionRate,
      'directPaymentCommission': directPaymentCommission,
      'minimumWithdrawAmount': minimumWithdrawAmount,
      'paymentDeadlineHours': paymentDeadlineHours,
      'promoCodeMaxDiscount': promoCodeMaxDiscount,
      'freeSessionEnabled': freeSessionEnabled,
      'maxActiveSubscriptions': maxActiveSubscriptions,
      'slotLockDurationMinutes': slotLockDurationMinutes,
      'maxPendingRequestsPerStudent': maxPendingRequestsPerStudent,
      'sessionReminderHours1': sessionReminderHours1,
      'sessionReminderHours2': sessionReminderHours2,
      'maxAdvanceBookingDays': maxAdvanceBookingDays,
      'maintenanceMode': maintenanceMode,
      'maintenanceMessage': maintenanceMessage,
      'maintenanceAllowedUids': maintenanceAllowedUids,
      'forceUpdateVersion': forceUpdateVersion,
      'recommendedUpdateVersion': recommendedUpdateVersion,
      'maxImageUploadSizeMB': maxImageUploadSizeMB,
      'defaultSearchRadiusKm': defaultSearchRadiusKm,
      'maxSearchRadiusKm': maxSearchRadiusKm,
      'enableOnlineSessions': enableOnlineSessions,
      'enableMosqueSessions': enableMosqueSessions,
      'enableHomeSessions': enableHomeSessions,
      'fcmEnabled': fcmEnabled,
      'paymentReminderEnabled': paymentReminderEnabled,
      'sessionReminderEnabled': sessionReminderEnabled,
      'commissionJobEnabled': commissionJobEnabled,
      'credentialReviewRequired': credentialReviewRequired,
      'autoApproveMohaffez': autoApproveMohaffez,
      'allowUnverifiedBooking': allowUnverifiedBooking,
      'maxCredentialFiles': maxCredentialFiles,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updatedBy': updatedBy,
      'adminWallets': adminWallets,
    };
  }
}
