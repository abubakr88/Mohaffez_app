import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/direct_payment_model.dart';

class DirectPaymentService {
  static final _functions = FirebaseFunctions.instance;
  static final _db = FirebaseFirestore.instance;

  // ── Teacher: save wallet numbers ─────────────────────────────────────────
  static Future<void> saveMohaffezWalletNumbers({
    required String mohaffezId,
    String? instapayNumber,
    String? vodafoneNumber,
    String? orangeNumber,
    String? etisalatNumber,
    String? wePayNumber,
  }) async {
    await _db.collection('users').doc(mohaffezId).update({
      'walletNumbers': {
        'instapay':      instapayNumber?.trim(),
        'vodafone_cash': vodafoneNumber?.trim(),
        'orange_money':  orangeNumber?.trim(),
        'etisalat_cash': etisalatNumber?.trim(),
        'we_pay':        wePayNumber?.trim(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Fetch teacher wallet numbers ─────────────────────────────────────────
  static Future<Map<String, String?>> getMohaffezWalletNumbers(
      String mohaffezId) async {
    final doc = await _db.collection('users').doc(mohaffezId).get();
    final wallets =
        doc.data()?['walletNumbers'] as Map<String, dynamic>? ?? {};
    return wallets.map((k, v) => MapEntry(k, v as String?));
  }

  // ── Student: mark payment sent ───────────────────────────────────────────
  // WHY: Called when student claims to have paid via direct payment method.
  // BUG-12 FIX: Now forwards bundle plan info (planType, planId, sessionsCount, validityDays)
  // to backend CF so mohaffez knows this is a bundle payment.
  // BUG-A FIX: Made requestId and slot fields nullable for bundle purchases
  static Future<Map<String, dynamic>> studentMarkPaid({
    // BUG-A FIX: Made nullable for bundle purchases
    String? requestId,
    required String mohaffezId,
    required String mohaffezName,
    required String studentName,
    // BUG-A FIX: Added studentEmail and studentPhone
    String studentEmail = '',
    String studentPhone = '',
    required double amount,
    required String sessionType,
    required String preferredTimeSlot,
    // BUG-A FIX: Made nullable for bundle purchases
    DateTime? slotDate,
    DateTime? slotStart,
    DateTime? slotEnd,
    required String paymentMethod,
    String? studentNote,
    String? imamAddressText,
    double? imamAddressLat,
    double? imamAddressLng,
    String? mohaffezPhone,
    // BUG-12 FIX: Bundle plan fields
    // BUG-A FIX: Added planTitle
    String? planType,
    String? planId,
    String? planTitle,
    int? sessionsCount,
    int? validityDays,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(
            'studentMarkedDirectPayment',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call({
        if (requestId != null)   'requestId': requestId,
        'mohaffezId':         mohaffezId,
        'mohaffezName':       mohaffezName,
        'studentName':        studentName,
        if (studentEmail.isNotEmpty) 'studentEmail': studentEmail,
        if (studentPhone.isNotEmpty) 'studentPhone': studentPhone,
        'amount':             amount,
        'sessionType':        sessionType,
        'preferredTimeSlot':  preferredTimeSlot,
        if (slotDate != null)         'slotDate': slotDate!.toIso8601String(),
        if (slotStart != null)        'slotStart': slotStart!.toIso8601String(),
        if (slotEnd != null)          'slotEnd': slotEnd!.toIso8601String(),
        'paymentMethod':      paymentMethod,
        if (studentNote != null)    'studentNote':    studentNote,
        if (imamAddressText != null) 'imamAddressText': imamAddressText,
        if (imamAddressLat != null)  'imamAddressLat':  imamAddressLat,
        if (imamAddressLng != null)  'imamAddressLng':  imamAddressLng,
        if (mohaffezPhone != null)   'mohaffezPhone':   mohaffezPhone,
        // BUG-12 FIX: Forward bundle plan fields to backend
        if (planType != null)       'planType': planType,
        if (planId != null)          'planId': planId,
        if (planTitle != null)        'planTitle': planTitle,
        if (sessionsCount != null)   'sessionsCount': sessionsCount,
        if (validityDays != null)     'validityDays': validityDays,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      // Idempotent success — already submitted
      if (e.code == 'already-exists') {
        try {
          final msg = e.message ?? '{}';
          final parsed = Map<String, dynamic>.from(
            (msg.startsWith('{')) ? _parseJson(msg) : {'success': true},
          );
          return parsed;
        } catch (_) {
          return {'success': true, 'message': e.message};
        }
      }
      rethrow;
    }
  }

  // ── Mohaffez: confirm payment received ───────────────────────────────────
  static Future<Map<String, dynamic>> mohaffezConfirm(
      String directPaymentRequestId) async {
    try {
      final result = await _functions
          .httpsCallable(
            'mohaffezConfirmDirectPayment',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call({'directPaymentRequestId': directPaymentRequestId});
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        return {'success': true, 'message': e.message};
      }
      rethrow;
    }
  }

    // WHY: Called when mohaffez confirms a bundle/subscription payment.
    // BUG-2+3 FIX: Creates a subscription instead of a single session.
  static Future<void> mohaffezConfirmBundlePayment({
    required String paymentId,
  }) async {
    final callable = FirebaseFunctions.instance
        .httpsCallable('confirmBundleDirectPayment');
    await callable.call({'paymentId': paymentId});
  }

  // ── Mohaffez: reject payment ─────────────────────────────────────────────
  static Future<void> mohaffezReject(
      String directPaymentRequestId, String? reason) async {
    try {
      await _functions
          .httpsCallable(
            'mohaffezRejectDirectPayment',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call({
        'directPaymentRequestId': directPaymentRequestId,
        if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') return; // already rejected, fine
      rethrow;
    }
  }

  // ── Stream pending confirmations for mohaffez ────────────────────────────
  static Stream<List<DirectPaymentModel>> watchPendingConfirmations(
      String mohaffezId) {
    return _db
        .collection('directPaymentRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pending_confirmation')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => DirectPaymentModel.fromFirestore(d)).toList());
  }

  // ── Stream weekly commission summaries for mohaffez ──────────────────────
  static Stream<List<WeeklyCommissionSummary>> watchCommissions(
      String mohaffezId) {
    return _db
        .collection('weeklyCommissionSummaries')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('weekNumber', descending: true)
        .limit(12)
        .snapshots()
        .map((s) => s.docs
            .map((d) => WeeklyCommissionSummary.fromFirestore(d))
            .toList());
  }

  // ── Stream ALL commission summaries (admin view) ─────────────────────────
  static Stream<List<WeeklyCommissionSummary>> watchAllCommissions() {
    return _db
        .collection('weeklyCommissionSummaries')
        .orderBy('dueDate', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs
            .map((d) => WeeklyCommissionSummary.fromFirestore(d))
            .toList());
  }

  // ── Fetch admin wallet numbers ─────────────────────────────────────────────
  static Future<Map<String, String?>> getAdminWalletNumbers() async {
    final doc = await _db
        .collection('systemConfig')
        .doc('global')
        .get();
    final data = doc.data() ?? {};
    final wallets = data['adminWallets'] as Map<String, dynamic>? ?? {};
    return {
      'instapay': wallets['instapay'] as String?,
      'vodafonecash': wallets['vodafonecash'] as String?,
      'orangemoney': wallets['orangemoney'] as String?,
    };
  }

  // ── Notify admin of commission payment ───────────────────────────────────
  static Future<void> notifyAdminOfCommissionPayment({
    required String mohaffezId,
    required String mohaffezName,
    required String summaryId,
    required double amount,
    String? note,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Update summary status → awaiting_confirmation
    final summaryRef = FirebaseFirestore.instance
        .collection('weeklyCommissionSummaries')
        .doc(summaryId);
    batch.update(summaryRef, {
      'status': 'awaiting_confirmation',
      'paymentClaimedAt': FieldValue.serverTimestamp(),
      'paymentClaimedBy': mohaffezId,
      'paymentNote': note,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Send notification to admin
    final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
    batch.set(notifRef, {
      'type': 'commission_payment_claimed',
      'userId': 'admin',
      'senderId': mohaffezId,
      'title': 'طلب تأكيد عمولة',
      'body': '$mohaffezName أرسل دفعة بقيمة ${amount.toStringAsFixed(2)} ج.م',
      'isRead': false,
      'highPriority': true,
      'data': {
        'weeklyCommissionSummaryId': summaryId,
        'mohaffezId': mohaffezId,
        'amount': amount.toString(),
        'note': note,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Simple JSON parser for error messages ────────────────────────────────
  static Map<String, dynamic> _parseJson(String s) {
    // Minimal: handles {"success":true,"message":"..."} only
    final result = <String, dynamic>{};
    final clean = s.replaceAll('{', '').replaceAll('}', '').trim();
    for (final pair in clean.split(',')) {
      final kv = pair.split(':');
      if (kv.length >= 2) {
        final key = kv[0].trim().replaceAll('"', '');
        final val = kv.sublist(1).join(':').trim().replaceAll('"', '');
        if (val == 'true') {
          result[key] = true;
        } else if (val == 'false') {
          result[key] = false;
        } else {
          result[key] = val;
        }
      }
    }
    return result;
  }
}
