// CHANGES vs original:
// Added 5 plan fields: planType, planId, planTitle, sessionsCount, validityDays
// Added convenience getter: isBundle
// fromMap + toMap updated with safe defaults (backward-compatible with old docs)
// All existing fields, constructors, copyWith are preserved 100%

import 'package:cloud_firestore/cloud_firestore.dart';

class SessionRequestModel {
  final String id;
  final String studentId;
  final String studentName;
  final String mohaffezId;
  final String mohaffezName;
  final String sessionType;
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

  // ── NEW plan fields ───────────────────────────────────────────────────────
  /// "single" | "bundle" | "subscription"
  final String planType;

  /// empty string for single-session requests
  final String planId;

  /// human-readable plan name; empty for single
  final String planTitle;

  /// always 1 for single-session requests
  final int sessionsCount;

  /// null when the plan has no expiry (or for single sessions)
  final int? validityDays;
  // ──────────────────────────────────────────────────────────────────────────

  const SessionRequestModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.mohaffezId,
    required this.mohaffezName,
    required this.sessionType,
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
    // plan fields — safe defaults keep old Firestore docs working seamlessly
    this.planType = 'single',
    this.planId = '',
    this.planTitle = '',
    this.sessionsCount = 1,
    this.validityDays,
  });

  /// true when this request is for a bundle or subscription purchase
  bool get isBundle => planType == 'bundle' || planType == 'subscription';

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
      mohaffezId: map['mohaffezId'] as String? ?? '',
      mohaffezName: map['mohaffezName'] as String? ?? '',
      sessionType: map['sessionType'] as String? ?? 'online',
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
      // NEW plan fields — defaults handle old docs that lack these fields
      planType: map['planType'] as String? ?? 'single',
      planId: map['planId'] as String? ?? '',
      planTitle: map['planTitle'] as String? ?? '',
      sessionsCount: (map['sessionsCount'] as num?)?.toInt() ?? 1,
      validityDays: (map['validityDays'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentName': studentName,
        'mohaffezId': mohaffezId,
        'mohaffezName': mohaffezName,
        'sessionType': sessionType,
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
        if (cancellationReason != null) 'cancellationReason': cancellationReason,
        if (cancelledBy != null) 'cancelledBy': cancelledBy,
        if (paymentAmount != null) 'paymentAmount': paymentAmount,
        if (isPaid != null) 'isPaid': isPaid,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
        // plan fields always written so Firestore queries can filter on them
        'planType': planType,
        'planId': planId,
        'planTitle': planTitle,
        'sessionsCount': sessionsCount,
        'validityDays': validityDays,
      };

  SessionRequestModel copyWith({
    String? status,
    String? sessionId,
    String? selectedPaymentMethod,
    String? subscriptionId,
    bool? isPaid,
    String? cancellationReason,
    String? cancelledBy,
  }) =>
      SessionRequestModel(
        id: id,
        studentId: studentId,
        studentName: studentName,
        mohaffezId: mohaffezId,
        mohaffezName: mohaffezName,
        sessionType: sessionType,
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
        // plan fields always carried through copyWith unchanged
        planType: planType,
        planId: planId,
        planTitle: planTitle,
        sessionsCount: sessionsCount,
        validityDays: validityDays,
      );
}
