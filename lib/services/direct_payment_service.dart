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
  static Future<Map<String, dynamic>> studentMarkPaid({
    required String requestId,
    required String mohaffezId,
    required String mohaffezName,
    required String studentName,
    required double amount,
    required String sessionType,
    required String preferredTimeSlot,
    required DateTime slotDate,
    required DateTime slotStart,
    required DateTime slotEnd,
    required String paymentMethod,
    String? studentNote,
    String? imamAddressText,
    double? imamAddressLat,
    double? imamAddressLng,
    String? mohaffezPhone,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(
            'studentMarkedDirectPayment',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call({
        'requestId':          requestId,
        'mohaffezId':         mohaffezId,
        'mohaffezName':       mohaffezName,
        'studentName':        studentName,
        'amount':             amount,
        'sessionType':        sessionType,
        'preferredTimeSlot':  preferredTimeSlot,
        'slotDate':           slotDate.toIso8601String(),
        'slotStart':          slotStart.toIso8601String(),
        'slotEnd':            slotEnd.toIso8601String(),
        'paymentMethod':      paymentMethod,
        if (studentNote != null)    'studentNote':    studentNote,
        if (imamAddressText != null) 'imamAddressText': imamAddressText,
        if (imamAddressLat != null)  'imamAddressLat':  imamAddressLat,
        if (imamAddressLng != null)  'imamAddressLng':  imamAddressLng,
        if (mohaffezPhone != null)   'mohaffezPhone':   mohaffezPhone,
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
        if (val == 'true') result[key] = true;
        else if (val == 'false') result[key] = false;
        else result[key] = val;
      }
    }
    return result;
  }
}
