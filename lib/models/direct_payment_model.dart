import 'package:cloud_firestore/cloud_firestore.dart';

enum DirectPaymentStatus { pendingConfirmation, confirmed, rejected }

enum DirectPaymentMethod {
  instapay,
  vodafoneCash,
  orangeMoney,
  etisalatCash,
  wePay;

  String get label => switch (this) {
        DirectPaymentMethod.instapay     => 'InstaPay',
        DirectPaymentMethod.vodafoneCash => 'فودافون كاش',
        DirectPaymentMethod.orangeMoney  => 'أورنج موني',
        DirectPaymentMethod.etisalatCash => 'اتصالات كاش',
        DirectPaymentMethod.wePay        => 'WE Pay',
      };

  // These MUST match the keys in users/{id}.walletNumbers in Firestore
  // and the keys saved by saveMohaffezWalletNumbers()
  String get value => switch (this) {
        DirectPaymentMethod.instapay     => 'instapay',
        DirectPaymentMethod.vodafoneCash => 'vodafone_cash',
        DirectPaymentMethod.orangeMoney  => 'orange_money',
        DirectPaymentMethod.etisalatCash => 'etisalat_cash',
        DirectPaymentMethod.wePay        => 'we_pay',
      };

  static DirectPaymentMethod fromValue(String v) =>
      DirectPaymentMethod.values.firstWhere(
        (e) => e.value == v,
        orElse: () => DirectPaymentMethod.instapay,
      );
}

class DirectPaymentModel {
  final String id;
  final String sessionRequestId;
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

  const DirectPaymentModel({
    required this.id,
    required this.sessionRequestId,
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
  });

  factory DirectPaymentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    // direct_payment_model.dart — parseStatus()
    DirectPaymentStatus parseStatus(String? s) {
      switch (s) {
        case 'confirmed':   return DirectPaymentStatus.confirmed;
        case 'rejected':    return DirectPaymentStatus.rejected;
        case 'pendingconfirmation': return DirectPaymentStatus.pendingConfirmation;
        // ✅ ADD THIS:
        case 'awaitingdirectpaymentconfirmation':
          return DirectPaymentStatus.pendingConfirmation;
        default:
          return DirectPaymentStatus.pendingConfirmation;
      }
    }
    
    DateTime? parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return DirectPaymentModel(
      id:                  doc.id,
      sessionRequestId:    d['sessionRequestId']    ?? '',
      studentId:           d['studentId']           ?? '',
      studentName:         d['studentName']         ?? '',
      mohaffezId:          d['mohaffezId']          ?? '',
      mohaffezName:        d['mohaffezName']        ?? '',
      amount:              (d['amount']             as num?)?.toDouble() ?? 0,
      commissionAmount:    (d['commissionAmount']   as num?)?.toDouble() ?? 0,
      commissionRate:      (d['commissionRate']     as num?)?.toDouble() ?? 0.05,
      sessionType:         d['sessionType']         ?? '',
      preferredTimeSlot:   d['preferredTimeSlot']   ?? '',
      sessionDate:         parseTs(d['sessionDate']),
      paymentMethod:       d['paymentMethod']       ?? '',
      studentNote:         d['studentNote'],
      sessionId:           d['sessionId'],
      status:              parseStatus(d['status']),
      studentConfirmedAt:  parseTs(d['studentConfirmedAt']),
      mohaffezConfirmedAt: parseTs(d['mohaffezConfirmedAt']),
      createdAt:           parseTs(d['createdAt']),
    );
  }
}

class WeeklyCommissionSummary {
  final String id;
  final String mohaffezId;
  final String mohaffezName;
  final int weekNumber;
  final int year;
  final int totalSessions;
  final double totalRevenue;
  final double commissionAmount;
  final double commissionRate;
  final String status; // 'pending' | 'paid' | 'overdue'
  final DateTime? weekStart;
  final DateTime? weekEnd;
  final DateTime? dueDate;
  final DateTime? paidAt;

  const WeeklyCommissionSummary({
    required this.id,
    required this.mohaffezId,
    required this.mohaffezName,
    required this.weekNumber,
    required this.year,
    this.totalSessions = 0,
    this.totalRevenue = 0,
    this.commissionAmount = 0,
    this.commissionRate = 0.05,
    this.status = 'pending',
    this.weekStart,
    this.weekEnd,
    this.dueDate,
    this.paidAt,
  });

  bool get isPending => status == 'pending';
  bool get isOverdue  => status == 'overdue';
  bool get isPaid     => status == 'paid';
  bool get isAwaitingConfirmation => status == 'awaiting_confirmation';
  bool get isActionable => isPending || isOverdue;

  factory WeeklyCommissionSummary.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }
    return WeeklyCommissionSummary(
      id:               doc.id,
      mohaffezId:       d['mohaffezId']       ?? '',
      mohaffezName:     d['mohaffezName']     ?? '',
      weekNumber:       d['weekNumber']       ?? 0,
      year:             d['year']             ?? DateTime.now().year,
      totalSessions:    d['totalSessions']    ?? 0,
      totalRevenue:     (d['totalRevenue']    as num?)?.toDouble() ?? 0,
      commissionAmount: (d['commissionAmount'] as num?)?.toDouble() ?? 0,
      commissionRate:   (d['commissionRate']  as num?)?.toDouble() ?? 0.05,
      status:           d['status']           ?? 'pending',
      weekStart:        ts(d['weekStart']),
      weekEnd:          ts(d['weekEnd']),
      dueDate:          ts(d['dueDate']),
      paidAt:           ts(d['paidAt']),
    );
  }
}
