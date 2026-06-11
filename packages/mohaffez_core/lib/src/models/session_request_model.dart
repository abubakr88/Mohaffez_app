// lib/models/session_request_model.dart
// CHANGES vs original:
// • Added rejectionReason + rejectedAt fields
// • fromMap, toMap, copyWith updated accordingly
// • All existing fields 100% preserved

import 'package:cloud_firestore/cloud_firestore.dart';

class SessionRequestModel {
  final String id;
  final String studentId;
  final String studentName;
  final int? studentAge;
  final String mohaffezId;
  final String mohaffezName;
  final String sessionType;
  final String?
      preferredProvider; // 'zoom' | 'googleMeet' | 'teams' (online only)
  final String preferredTimeSlot;
  final Timestamp? slotDate;
  final Timestamp? slotStart;
  final Timestamp? slotEnd;
  final String? imamAddressText;
  final double? imamAddressLat;
  final double? imamAddressLng;
  final String? mohaffezPhone;
  final String status;
  final String? selectedPaymentMethod;
  final String? subscriptionId;
  final bool requiresPaymentOnAcceptance;
  final String? slotLockId;
  final String? sessionId;
  final String? cancellationReason;
  final String? cancelledBy;
  final double? paymentAmount;
  final bool? isPaid;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  // ── NEW: rejection fields ──────────────────────────────────────────────────
  /// The reason the mohaffez rejected this request. Populated by rejectRequest().
  final String? rejectionReason;

  /// Server timestamp set when the request was rejected.
  final Timestamp? rejectedAt;
  // ──────────────────────────────────────────────────────────────────────────

  // ── Plan fields ───────────────────────────────────────────────────────────
  /// "single" | "bundle" | "subscription"
  final String planType;

  /// Empty string for single-session requests.
  final String planId;

  /// Human-readable plan name; empty for single.
  final String planTitle;

  /// Always 1 for single-session requests.
  final int sessionsCount;

  /// null when the plan has no expiry (or for single sessions).
  final int? validityDays;

  /// Direct payment request ID for pending confirmations.
  final String? directPaymentRequestId;
  // ──────────────────────────────────────────────────────────────────────────

  const SessionRequestModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentAge,
    required this.mohaffezId,
    required this.mohaffezName,
    required this.sessionType,
    this.preferredProvider,
    required this.preferredTimeSlot,
    this.slotDate,
    this.slotStart,
    this.slotEnd,
    this.imamAddressText,
    this.imamAddressLat,
    this.imamAddressLng,
    this.mohaffezPhone,
    required this.status,
    this.selectedPaymentMethod,
    this.subscriptionId,
    this.requiresPaymentOnAcceptance = false,
    this.slotLockId,
    this.sessionId,
    this.cancellationReason,
    this.cancelledBy,
    this.paymentAmount,
    this.isPaid,
    this.createdAt,
    this.updatedAt,
    // rejection fields
    this.rejectionReason,
    this.rejectedAt,
    // plan fields — safe defaults keep old Firestore docs working seamlessly
    this.planType = 'single',
    this.planId = '',
    this.planTitle = '',
    this.sessionsCount = 1,
    this.validityDays,
    this.directPaymentRequestId,
  });

  /// true when this request is for a bundle or subscription purchase.
  bool get isBundle => planType == 'bundle' || planType == 'subscription';

  /// true when this request was rejected by the mohaffez.
  bool get isRejected => status == 'rejected';

  factory SessionRequestModel.fromJson(Map<String, dynamic> json) =>
      SessionRequestModel.fromMap(json, json['id'] as String? ?? '');

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};

  factory SessionRequestModel.fromMap(Map<String, dynamic> map, String id) {
    double? toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return SessionRequestModel(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      studentAge: (map['studentAge'] as num?)?.toInt(),
      mohaffezId: map['mohaffezId'] as String? ?? '',
      mohaffezName: map['mohaffezName'] as String? ?? '',
      sessionType: map['sessionType'] as String? ?? 'online',
      preferredProvider: map['preferredProvider'] as String?,
      preferredTimeSlot: map['preferredTimeSlot'] as String? ?? '',
      slotDate: map['slotDate'] as Timestamp?,
      slotStart: map['slotStart'] as Timestamp?,
      slotEnd: map['slotEnd'] as Timestamp?,
      imamAddressText: map['imamAddressText'] as String?,
      imamAddressLat: toDouble(map['imamAddressLat']),
      imamAddressLng: toDouble(map['imamAddressLng']),
      mohaffezPhone: map['mohaffezPhone'] as String?,
      status: map['status'] as String? ?? 'pending',
      selectedPaymentMethod: map['selectedPaymentMethod'] as String?,
      subscriptionId: map['subscriptionId'] as String?,
      requiresPaymentOnAcceptance:
          map['requiresPaymentOnAcceptance'] as bool? ?? false,
      slotLockId: map['slotLockId'] as String?,
      sessionId: map['sessionId'] as String?,
      cancellationReason: map['cancellationReason'] as String?,
      cancelledBy: map['cancelledBy'] as String?,
      paymentAmount: toDouble(map['paymentAmount']),
      isPaid: map['isPaid'] as bool?,
      createdAt: map['createdAt'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp?,
      // FIX: deserialize rejection fields
      rejectionReason: map['rejectionReason'] as String?,
      rejectedAt: map['rejectedAt'] as Timestamp?,
      // plan fields — defaults handle old docs that lack these fields
      planType: map['planType'] as String? ?? 'single',
      planId: map['planId'] as String? ?? '',
      planTitle: map['planTitle'] as String? ?? '',
      sessionsCount: (map['sessionsCount'] as num?)?.toInt() ?? 1,
      validityDays: (map['validityDays'] as num?)?.toInt(),
      directPaymentRequestId: map['directPaymentRequestId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentName': studentName,
        if (studentAge != null) 'studentAge': studentAge,
        'mohaffezId': mohaffezId,
        'mohaffezName': mohaffezName,
        'sessionType': sessionType,
        if (preferredProvider != null) 'preferredProvider': preferredProvider,
        'preferredTimeSlot': preferredTimeSlot,
        if (slotDate != null) 'slotDate': slotDate,
        if (slotStart != null) 'slotStart': slotStart,
        if (slotEnd != null) 'slotEnd': slotEnd,
        if (imamAddressText != null) 'imamAddressText': imamAddressText,
        if (imamAddressLat != null) 'imamAddressLat': imamAddressLat,
        if (imamAddressLng != null) 'imamAddressLng': imamAddressLng,
        if (mohaffezPhone != null) 'mohaffezPhone': mohaffezPhone,
        'status': status,
        if (selectedPaymentMethod != null)
          'selectedPaymentMethod': selectedPaymentMethod,
        if (subscriptionId != null) 'subscriptionId': subscriptionId,
        'requiresPaymentOnAcceptance': requiresPaymentOnAcceptance,
        if (slotLockId != null) 'slotLockId': slotLockId,
        if (sessionId != null) 'sessionId': sessionId,
        if (cancellationReason != null)
          'cancellationReason': cancellationReason,
        if (cancelledBy != null) 'cancelledBy': cancelledBy,
        if (paymentAmount != null) 'paymentAmount': paymentAmount,
        if (isPaid != null) 'isPaid': isPaid,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
        // FIX: always persist rejection fields when present
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (rejectedAt != null) 'rejectedAt': rejectedAt,
        // plan fields always written so Firestore queries can filter on them
        'planType': planType,
        'planId': planId,
        'planTitle': planTitle,
        'sessionsCount': sessionsCount,
        'validityDays': validityDays,
        if (directPaymentRequestId != null)
          'directPaymentRequestId': directPaymentRequestId,
      };

  SessionRequestModel copyWith({
    String? status,
    String? sessionId,
    String? selectedPaymentMethod,
    String? subscriptionId,
    bool? isPaid,
    String? cancellationReason,
    String? cancelledBy,
    // FIX: rejection fields now copyable
    String? rejectionReason,
    Timestamp? rejectedAt,
  }) =>
      SessionRequestModel(
        id: id,
        studentId: studentId,
        studentName: studentName,
        studentAge: studentAge,
        mohaffezId: mohaffezId,
        mohaffezName: mohaffezName,
        sessionType: sessionType,
        preferredProvider: preferredProvider,
        preferredTimeSlot: preferredTimeSlot,
        slotDate: slotDate,
        slotStart: slotStart,
        slotEnd: slotEnd,
        imamAddressText: imamAddressText,
        imamAddressLat: imamAddressLat,
        imamAddressLng: imamAddressLng,
        mohaffezPhone: mohaffezPhone,
        status: status ?? this.status,
        selectedPaymentMethod:
            selectedPaymentMethod ?? this.selectedPaymentMethod,
        subscriptionId: subscriptionId ?? this.subscriptionId,
        requiresPaymentOnAcceptance: requiresPaymentOnAcceptance,
        slotLockId: slotLockId,
        sessionId: sessionId ?? this.sessionId,
        cancellationReason: cancellationReason ?? this.cancellationReason,
        cancelledBy: cancelledBy ?? this.cancelledBy,
        paymentAmount: paymentAmount,
        isPaid: isPaid ?? this.isPaid,
        createdAt: createdAt,
        updatedAt: updatedAt,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        rejectedAt: rejectedAt ?? this.rejectedAt,
        // plan fields always carried through unchanged
        planType: planType,
        planId: planId,
        planTitle: planTitle,
        sessionsCount: sessionsCount,
        validityDays: validityDays,
        directPaymentRequestId: directPaymentRequestId,
      );
}
