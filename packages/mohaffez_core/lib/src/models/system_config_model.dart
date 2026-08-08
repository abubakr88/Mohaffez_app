import 'package:cloud_firestore/cloud_firestore.dart';

import 'commission_tier_model.dart';

class SystemConfigModel {
  final double commissionRate;
  final double directPaymentCommission;
  final double minimumWithdrawAmount;
  final double minimumTeacherHourlyRateEgp;
  final int minimumIndependentStudentAge;
  final int discoveryChildrenMaxAge;
  final int discoveryTeenMaxAge;
  final bool discoveryAudienceMatchingEnabled;
  final bool allowIncompleteTeacherAudience;
  final int paymentDeadlineHours;
  final int promoCodeMaxDiscount;
  final bool freeSessionEnabled;
  final bool challengeV2Enabled;
  final int maxActiveSubscriptions;
  final int slotLockDurationMinutes;
  final int maxPendingRequestsPerStudent;
  final int sessionReminderHours1;
  final int sessionReminderHours2;
  final int maxAdvanceBookingDays;
  final int meetingStartLeadTimeMinutes;
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
  final bool variablePlanSessionDurationEnabled;
  final bool fcmEnabled;
  final bool paymentReminderEnabled;
  final bool sessionReminderEnabled;
  final bool commissionJobEnabled;
  final bool credentialReviewRequired;
  final bool teacherRegistrationEnabled;
  final bool autoApproveMohaffez;
  final bool allowUnverifiedBooking;
  final bool paymobEnabled;
  final int maxCredentialFiles;
  final double examPassingScore;
  final int examMaxRetries;
  final int examRetryCooldownDays;
  final DateTime? updatedAt;
  final String updatedBy;
  final Map<String, String?> adminWallets;
  final List<CommissionTierModel> commissionTiers;

  /// Sessions that started more than this many minutes after their
  /// scheduled time are flagged `startedLate: true` on `hafizSessions`
  /// and excluded from tier calculations. Configurable by admin.
  final int lateSessionGraceMinutes;

  /// Maximum allowed duration (in minutes) for a session once the teacher
  /// taps "Start". A scheduled Cloud Function auto-completes sessions
  /// whose `meetingStartedAt` is older than this and that are still not
  /// marked `completed`. Default: 90 minutes.
  final int sessionMaxDurationMinutes;

  /// Teachers whose `directCommissionOwedPiastres` debt exceeds this amount
  /// (in EGP) cannot accept new direct-payment bookings until they pay it
  /// down. Server-enforced. Default: 500 EGP.
  final double directPaymentDebtThresholdEgp;

  const SystemConfigModel({
    required this.commissionRate,
    required this.directPaymentCommission,
    required this.minimumWithdrawAmount,
    required this.minimumTeacherHourlyRateEgp,
    required this.minimumIndependentStudentAge,
    required this.discoveryChildrenMaxAge,
    required this.discoveryTeenMaxAge,
    required this.discoveryAudienceMatchingEnabled,
    required this.allowIncompleteTeacherAudience,
    required this.paymentDeadlineHours,
    required this.promoCodeMaxDiscount,
    required this.freeSessionEnabled,
    required this.challengeV2Enabled,
    required this.maxActiveSubscriptions,
    required this.slotLockDurationMinutes,
    required this.maxPendingRequestsPerStudent,
    required this.sessionReminderHours1,
    required this.sessionReminderHours2,
    required this.maxAdvanceBookingDays,
    required this.meetingStartLeadTimeMinutes,
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
    required this.variablePlanSessionDurationEnabled,
    required this.fcmEnabled,
    required this.paymentReminderEnabled,
    required this.sessionReminderEnabled,
    required this.commissionJobEnabled,
    required this.credentialReviewRequired,
    required this.teacherRegistrationEnabled,
    required this.autoApproveMohaffez,
    required this.allowUnverifiedBooking,
    required this.paymobEnabled,
    required this.maxCredentialFiles,
    required this.examPassingScore,
    required this.examMaxRetries,
    required this.examRetryCooldownDays,
    required this.updatedAt,
    required this.updatedBy,
    required this.adminWallets,
    required this.commissionTiers,
    required this.lateSessionGraceMinutes,
    required this.sessionMaxDurationMinutes,
    required this.directPaymentDebtThresholdEgp,
  });

  factory SystemConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final defaults = SystemConfigModel.defaults();
    final updatedAt = data['updatedAt'];
    final configuredChildrenMaxAge =
        (data['discoveryChildrenMaxAge'] as num?)?.toInt() ??
            defaults.discoveryChildrenMaxAge;
    final configuredTeenMaxAge =
        (data['discoveryTeenMaxAge'] as num?)?.toInt() ??
            defaults.discoveryTeenMaxAge;
    final hasValidAudienceAges = configuredChildrenMaxAge >= 0 &&
        configuredChildrenMaxAge < configuredTeenMaxAge &&
        configuredTeenMaxAge <= 30;
    return SystemConfigModel(
      commissionRate: (data['commissionRate'] as num?)?.toDouble() ??
          defaults.commissionRate,
      directPaymentCommission:
          (data['directPaymentCommission'] as num?)?.toDouble() ??
              defaults.directPaymentCommission,
      minimumWithdrawAmount:
          (data['minimumWithdrawAmount'] as num?)?.toDouble() ??
              defaults.minimumWithdrawAmount,
      minimumTeacherHourlyRateEgp:
          (data['minimumTeacherHourlyRateEgp'] as num?)?.toDouble() ??
              defaults.minimumTeacherHourlyRateEgp,
      minimumIndependentStudentAge:
          ((data['minimumIndependentStudentAge'] as num?)?.toInt() ??
                  defaults.minimumIndependentStudentAge)
              .clamp(5, 30)
              .toInt(),
      discoveryChildrenMaxAge: hasValidAudienceAges
          ? configuredChildrenMaxAge
          : defaults.discoveryChildrenMaxAge,
      discoveryTeenMaxAge: hasValidAudienceAges
          ? configuredTeenMaxAge
          : defaults.discoveryTeenMaxAge,
      discoveryAudienceMatchingEnabled:
          data['discoveryAudienceMatchingEnabled'] as bool? ??
              defaults.discoveryAudienceMatchingEnabled,
      allowIncompleteTeacherAudience:
          data['allowIncompleteTeacherAudience'] as bool? ??
              defaults.allowIncompleteTeacherAudience,
      paymentDeadlineHours: (data['paymentDeadlineHours'] as num?)?.toInt() ??
          defaults.paymentDeadlineHours,
      promoCodeMaxDiscount: (data['promoCodeMaxDiscount'] as num?)?.toInt() ??
          defaults.promoCodeMaxDiscount,
      freeSessionEnabled:
          data['freeSessionEnabled'] as bool? ?? defaults.freeSessionEnabled,
      challengeV2Enabled:
          data['challengeV2Enabled'] as bool? ?? defaults.challengeV2Enabled,
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
      meetingStartLeadTimeMinutes:
          (data['meetingStartLeadTimeMinutes'] as num?)?.toInt() ??
              defaults.meetingStartLeadTimeMinutes,
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
      variablePlanSessionDurationEnabled:
          data['variablePlanSessionDurationEnabled'] as bool? ??
              defaults.variablePlanSessionDurationEnabled,
      fcmEnabled: data['fcmEnabled'] as bool? ?? defaults.fcmEnabled,
      paymentReminderEnabled: data['paymentReminderEnabled'] as bool? ??
          defaults.paymentReminderEnabled,
      sessionReminderEnabled: data['sessionReminderEnabled'] as bool? ??
          defaults.sessionReminderEnabled,
      commissionJobEnabled: data['commissionJobEnabled'] as bool? ??
          defaults.commissionJobEnabled,
      credentialReviewRequired: data['credentialReviewRequired'] as bool? ??
          defaults.credentialReviewRequired,
      teacherRegistrationEnabled: data['teacherRegistrationEnabled'] as bool? ??
          defaults.teacherRegistrationEnabled,
      autoApproveMohaffez:
          data['autoApproveMohaffez'] as bool? ?? defaults.autoApproveMohaffez,
      allowUnverifiedBooking: data['allowUnverifiedBooking'] as bool? ??
          defaults.allowUnverifiedBooking,
      paymobEnabled: data['paymobEnabled'] as bool? ?? defaults.paymobEnabled,
      maxCredentialFiles: (data['maxCredentialFiles'] as num?)?.toInt() ??
          defaults.maxCredentialFiles,
      examPassingScore: (data['examPassingScore'] as num?)?.toDouble() ??
          defaults.examPassingScore,
      examMaxRetries:
          (data['examMaxRetries'] as num?)?.toInt() ?? defaults.examMaxRetries,
      examRetryCooldownDays: (data['examRetryCooldownDays'] as num?)?.toInt() ??
          defaults.examRetryCooldownDays,
      updatedAt:
          updatedAt is Timestamp ? updatedAt.toDate() : defaults.updatedAt,
      updatedBy: data['updatedBy'] as String? ?? defaults.updatedBy,
      adminWallets: Map<String, String?>.from(
        (data['adminWallets'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as String?)),
      ),
      commissionTiers: (data['commissionTiers'] as List<dynamic>?)
              ?.map((e) => CommissionTierModel.fromMap(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          defaults.commissionTiers,
      lateSessionGraceMinutes:
          (data['lateSessionGraceMinutes'] as num?)?.toInt() ??
              defaults.lateSessionGraceMinutes,
      sessionMaxDurationMinutes:
          (data['sessionMaxDurationMinutes'] as num?)?.toInt() ??
              defaults.sessionMaxDurationMinutes,
      directPaymentDebtThresholdEgp:
          (data['directPaymentDebtThresholdEgp'] as num?)?.toDouble() ??
              defaults.directPaymentDebtThresholdEgp,
    );
  }

  factory SystemConfigModel.defaults() {
    return const SystemConfigModel(
      commissionRate: 0.05,
      directPaymentCommission: 0.05,
      minimumWithdrawAmount: 100.0,
      minimumTeacherHourlyRateEgp: 0.0,
      minimumIndependentStudentAge: 18,
      discoveryChildrenMaxAge: 10,
      discoveryTeenMaxAge: 15,
      discoveryAudienceMatchingEnabled: true,
      allowIncompleteTeacherAudience: true,
      paymentDeadlineHours: 48,
      promoCodeMaxDiscount: 100,
      freeSessionEnabled: true,
      challengeV2Enabled: true,
      maxActiveSubscriptions: 3,
      slotLockDurationMinutes: 120,
      maxPendingRequestsPerStudent: 5,
      sessionReminderHours1: 24,
      sessionReminderHours2: 1,
      maxAdvanceBookingDays: 30,
      meetingStartLeadTimeMinutes: 60,
      maintenanceMode: false,
      maintenanceMessage: '',
      maintenanceAllowedUids: [],
      forceUpdateVersion: '1.0.0',
      recommendedUpdateVersion: '1.0.0',
      maxImageUploadSizeMB: 5,
      defaultSearchRadiusKm: 50,
      maxSearchRadiusKm: 150,
      enableOnlineSessions: true,
      enableMosqueSessions: true,
      enableHomeSessions: true,
      variablePlanSessionDurationEnabled: false,
      fcmEnabled: true,
      paymentReminderEnabled: true,
      sessionReminderEnabled: true,
      commissionJobEnabled: true,
      credentialReviewRequired: true,
      teacherRegistrationEnabled: true,
      autoApproveMohaffez: false,
      allowUnverifiedBooking: false,
      paymobEnabled: false,
      maxCredentialFiles: 5,
      examPassingScore: 70.0,
      examMaxRetries: 3,
      examRetryCooldownDays: 3,
      updatedAt: null,
      updatedBy: '',
      adminWallets: {},
      commissionTiers: CommissionTierModel.defaultTiers,
      lateSessionGraceMinutes: 10,
      sessionMaxDurationMinutes: 90,
      directPaymentDebtThresholdEgp: 500.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commissionRate': commissionRate,
      'directPaymentCommission': directPaymentCommission,
      'minimumWithdrawAmount': minimumWithdrawAmount,
      'minimumTeacherHourlyRateEgp': minimumTeacherHourlyRateEgp,
      'minimumIndependentStudentAge': minimumIndependentStudentAge,
      'discoveryChildrenMaxAge': discoveryChildrenMaxAge,
      'discoveryTeenMaxAge': discoveryTeenMaxAge,
      'discoveryAudienceMatchingEnabled': discoveryAudienceMatchingEnabled,
      'allowIncompleteTeacherAudience': allowIncompleteTeacherAudience,
      'paymentDeadlineHours': paymentDeadlineHours,
      'promoCodeMaxDiscount': promoCodeMaxDiscount,
      'freeSessionEnabled': freeSessionEnabled,
      'challengeV2Enabled': challengeV2Enabled,
      'maxActiveSubscriptions': maxActiveSubscriptions,
      'slotLockDurationMinutes': slotLockDurationMinutes,
      'maxPendingRequestsPerStudent': maxPendingRequestsPerStudent,
      'sessionReminderHours1': sessionReminderHours1,
      'sessionReminderHours2': sessionReminderHours2,
      'maxAdvanceBookingDays': maxAdvanceBookingDays,
      'meetingStartLeadTimeMinutes': meetingStartLeadTimeMinutes,
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
      'variablePlanSessionDurationEnabled': variablePlanSessionDurationEnabled,
      'fcmEnabled': fcmEnabled,
      'paymentReminderEnabled': paymentReminderEnabled,
      'sessionReminderEnabled': sessionReminderEnabled,
      'commissionJobEnabled': commissionJobEnabled,
      'credentialReviewRequired': credentialReviewRequired,
      'teacherRegistrationEnabled': teacherRegistrationEnabled,
      'autoApproveMohaffez': autoApproveMohaffez,
      'allowUnverifiedBooking': allowUnverifiedBooking,
      'paymobEnabled': paymobEnabled,
      'maxCredentialFiles': maxCredentialFiles,
      'examPassingScore': examPassingScore,
      'examMaxRetries': examMaxRetries,
      'examRetryCooldownDays': examRetryCooldownDays,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updatedBy': updatedBy,
      'adminWallets': adminWallets,
      'commissionTiers': commissionTiers.map((t) => t.toMap()).toList(),
      'lateSessionGraceMinutes': lateSessionGraceMinutes,
      'sessionMaxDurationMinutes': sessionMaxDurationMinutes,
      'directPaymentDebtThresholdEgp': directPaymentDebtThresholdEgp,
    };
  }
}
