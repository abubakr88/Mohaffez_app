// lib/models/direct_payment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum DirectPaymentStatus { pendingConfirmation, confirmed, rejected }

enum DirectPaymentMethod {
  instapay,
  vodafoneCash,
  orangeMoney,
  etisalatCash,
  wePay;

  String get label => switch (this) {
        DirectPaymentMethod.instapay => 'InstaPay',
        DirectPaymentMethod.vodafoneCash => 'فودافون كاش',
        DirectPaymentMethod.orangeMoney => 'أورنج موني',
        DirectPaymentMethod.etisalatCash => 'اتصالات كاش',
        DirectPaymentMethod.wePay => 'WE Pay',
      };

  // These MUST match the keys in users/{id}.walletNumbers in Firestore
  // and the keys saved by saveMohaffezWalletNumbers()
  String get value => switch (this) {
        DirectPaymentMethod.instapay => 'instapay',
        DirectPaymentMethod.vodafoneCash => 'vodafonecash',
        DirectPaymentMethod.orangeMoney => 'orangemoney',
        DirectPaymentMethod.etisalatCash => 'etisalatcash',
        DirectPaymentMethod.wePay => 'wepay',
      };

  static DirectPaymentMethod fromValue(String v) =>
      DirectPaymentMethod.values.firstWhere(
        (e) => e.value == v,
        orElse: () => DirectPaymentMethod.instapay,
      );
}

class DirectPaymentModel {
  final String id;
  // FIX BUG-NEW-2
  final String? sessionRequestId;
  final String studentId;
  final String studentName;
  final String mohaffezId;
  final String mohaffezName;
  final double amount;
  final double commissionAmount;
  final double commissionRate;
  final String sessionType;
  final String preferredTimeSlot;
  final DateTime? sessionDate;
  final String paymentMethod;
  final String? studentNote;
  final String? sessionId;
  final DirectPaymentStatus status;
  final DateTime? studentConfirmedAt;
  final DateTime? mohaffezConfirmedAt;
  final DateTime? createdAt;
  // BUG-2+3 FIX: Bundle plan fields
  final String? planType;
  final String? planId;
  final String? planTitle; // FIX-1: Add planTitle for bundle confirmation
  final int? sessionsCount;
  final int? validityDays;
  // isSlotCoupled: slot fields for auto-booking first session
  final String? slotDate;
  final String? slotStart;
  final String? slotEnd;
  final int bookingTimeZoneVersion;
  final String? scheduleTimeZoneId;
  final String? teacherLocalDate;
  final String? teacherLocalTimeSlot;

  const DirectPaymentModel({
    required this.id,
    // FIX BUG-NEW-2
    this.sessionRequestId,
    required this.studentId,
    required this.studentName,
    required this.mohaffezId,
    required this.mohaffezName,
    required this.amount,
    required this.commissionAmount,
    this.commissionRate = 0.05,
    required this.sessionType,
    required this.preferredTimeSlot,
    this.sessionDate,
    required this.paymentMethod,
    this.studentNote,
    this.sessionId,
    this.status = DirectPaymentStatus.pendingConfirmation,
    this.studentConfirmedAt,
    this.mohaffezConfirmedAt,
    this.createdAt,
    // BUG-2+3 FIX: Initialize bundle fields
    this.planType,
    this.planId,
    this.planTitle,
    this.sessionsCount,
    this.validityDays,
    this.slotDate,
    this.slotStart,
    this.slotEnd,
    this.bookingTimeZoneVersion = 0,
    this.scheduleTimeZoneId,
    this.teacherLocalDate,
    this.teacherLocalTimeSlot,
  });

  factory DirectPaymentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    DirectPaymentStatus parseStatus(String? s) {
      switch (s) {
        case 'confirmed':
          return DirectPaymentStatus.confirmed;
        case 'rejected':
          return DirectPaymentStatus.rejected;
        case 'pendingconfirmation':
          return DirectPaymentStatus.pendingConfirmation;
        // Cloud Functions write this status for direct-payment requests
        case 'awaitingdirectpaymentconfirmation':
          return DirectPaymentStatus.pendingConfirmation;
        default:
          return DirectPaymentStatus.pendingConfirmation;
      }
    }

    // Handles Firestore Timestamp, ISO String, or null → DateTime?
    DateTime? parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    // FIX: Handles Firestore Timestamp OR ISO String OR null → String?
    // Root cause of crash: Cloud Functions write slotDate/slotStart/slotEnd
    // as Firestore Timestamp objects, but the model was casting them with
    // `as String?` which throws: "type 'Timestamp' is not a subtype of
    // type 'String?' in type cast".
    // This helper normalises both representations into an ISO-8601 string
    // so the rest of the app (which expects String?) continues to work.
    String? tsToIso(dynamic v) {
      if (v is Timestamp) return v.toDate().toIso8601String();
      if (v is String && v.isNotEmpty) return v;
      return null;
    }

    return DirectPaymentModel(
      id: doc.id,
      // FIX BUG-NEW-2
      sessionRequestId: d['sessionRequestId'] as String?,
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? '',
      mohaffezId: d['mohaffezId'] ?? '',
      mohaffezName: d['mohaffezName'] ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      commissionAmount: (d['commissionAmount'] as num?)?.toDouble() ?? 0,
      commissionRate: (d['commissionRate'] as num?)?.toDouble() ?? 0.05,
      sessionType: d['sessionType'] ?? '',
      preferredTimeSlot: d['preferredTimeSlot'] ?? '',
      sessionDate: parseTs(d['sessionDate']),
      paymentMethod: d['paymentMethod'] ?? '',
      studentNote: d['studentNote'],
      sessionId: d['sessionId'],
      status: parseStatus(d['status']),
      studentConfirmedAt: parseTs(d['studentConfirmedAt']),
      mohaffezConfirmedAt: parseTs(d['mohaffezConfirmedAt']),
      createdAt: parseTs(d['createdAt']),
      // BUG-2+3 FIX: Parse bundle fields
      planType: d['planType'],
      planId: d['planId'],
      planTitle: d['planTitle'],
      sessionsCount: d['sessionsCount'] as int?,
      validityDays: d['validityDays'] as int?,
      // FIX: was `d['slotDate'] as String?` — crashes when CF writes Timestamp
      slotDate: tsToIso(d['slotDate']),
      slotStart: tsToIso(d['slotStart']),
      slotEnd: tsToIso(d['slotEnd']),
      bookingTimeZoneVersion:
          (d['bookingTimeZoneVersion'] as num?)?.toInt() ?? 0,
      scheduleTimeZoneId: d['scheduleTimeZoneId'] as String?,
      teacherLocalDate: d['teacherLocalDate'] as String?,
      teacherLocalTimeSlot: d['teacherLocalTimeSlot'] as String?,
    );
  }
}
