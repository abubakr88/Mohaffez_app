import 'package:flutter/foundation.dart';
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
        'instapay': instapayNumber?.trim(),
        'vodafonecash': vodafoneNumber?.trim(),
        'orangemoney': orangeNumber?.trim(),
        'etisalatcash': etisalatNumber?.trim(),
        'wepay': wePayNumber?.trim(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Fetch teacher wallet numbers ─────────────────────────────────────────
  static Future<Map<String, String?>> getMohaffezWalletNumbers(
      String mohaffezId) async {
    final doc = await _db.collection('users').doc(mohaffezId).get();
    final wallets = doc.data()?['walletNumbers'] as Map<String, dynamic>? ?? {};
    return {
      'instapay': wallets['instapay'] as String?,
      // Backward compatible: read both old underscored keys and new canonical keys.
      'vodafonecash':
          (wallets['vodafonecash'] ?? wallets['vodafone_cash']) as String?,
      'orangemoney':
          (wallets['orangemoney'] ?? wallets['orange_money']) as String?,
      'etisalatcash':
          (wallets['etisalatcash'] ?? wallets['etisalat_cash']) as String?,
      'wepay': (wallets['wepay'] ?? wallets['we_pay']) as String?,
    };
  }

  // ── Student: mark payment sent ───────────────────────────────────────────
  // WHY: Called when student claims to have paid via direct payment method.
  // BUG-12 FIX: Now forwards bundle plan info (planType, planId, sessionsCount, validityDays)
  // to backend CF so mohaffez knows this is a bundle payment.
  // BUG-A FIX: Slot fields nullable for bundle purchases
  static Future<Map<String, dynamic>> studentMarkPaid({
    required String requestId,
    required String mohaffezId,
    required String mohaffezName,
    required String studentName,
    String studentEmail = '',
    String studentPhone = '',
    required double amount,
    required String sessionType,
    required String preferredTimeSlot,
    DateTime? slotDate,
    DateTime? slotStart,
    DateTime? slotEnd,
    required String paymentMethod,
    String? studentNote,
    String? imamAddressText,
    double? imamAddressLat,
    double? imamAddressLng,
    String? mohaffezPhone,
    String? planType,
    String? planId,
    String? planTitle,
    int? sessionsCount,
    int? validityDays,
    String? studentCountryCode,
    String? studentCountryName,
    String? displayCurrencyCode,
    String? displayCurrencyLabel,
    double? displayAmount,
    double? fxRateToEGP,
    double? chargedAmountEGP,
    int? sessionDurationMinutes,
    String? guardianId,
    String? guardianName,
    String? studentProfileId,
    String? studentProfileName,
    String? studentProfileGender,
    DateTime? studentProfileBirthDate,
    int? studentAge,
  }) async {
    assert(requestId.isNotEmpty, 'requestId must not be empty');
    if (kDebugMode) {
      debugPrint('🔵 [DirectPaymentService] studentMarkPaid: '
          'requestId=$requestId, mohaffezId=$mohaffezId, '
          'planType=$planType, planId=$planId, sessionsCount=$sessionsCount');
    }

    try {
      final result = await _functions
          .httpsCallable(
        'studentMarkedDirectPayment',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      )
          .call({
        'requestId': requestId,
        'mohaffezId': mohaffezId,
        'mohaffezName': mohaffezName,
        'studentName': studentName,
        if (guardianId != null) 'guardianId': guardianId,
        if (guardianName != null) 'guardianName': guardianName,
        if (studentProfileId != null) 'studentProfileId': studentProfileId,
        if (studentProfileName != null)
          'studentProfileName': studentProfileName,
        if (studentProfileGender != null)
          'studentProfileGender': studentProfileGender,
        if (studentProfileBirthDate != null)
          'studentProfileBirthDate':
              studentProfileBirthDate.toUtc().toIso8601String(),
        if (studentAge != null) 'studentAge': studentAge,
        if (studentEmail.isNotEmpty) 'studentEmail': studentEmail,
        if (studentPhone.isNotEmpty) 'studentPhone': studentPhone,
        'amount': amount,
        'sessionType': sessionType,
        'preferredTimeSlot': preferredTimeSlot,
        // Always send UTC. The server (parseFlutterDate) assumes any string
        // missing a timezone is UTC, so a naive local toIso8601String() ends
        // up stored as `+UTC_offset` hours into the future. Egypt = +3h shift.
        if (slotDate != null) 'slotDate': slotDate.toUtc().toIso8601String(),
        if (slotStart != null) 'slotStart': slotStart.toUtc().toIso8601String(),
        if (slotEnd != null) 'slotEnd': slotEnd.toUtc().toIso8601String(),
        'paymentMethod': paymentMethod,
        if (studentNote != null) 'studentNote': studentNote,
        if (imamAddressText != null) 'imamAddressText': imamAddressText,
        if (imamAddressLat != null) 'imamAddressLat': imamAddressLat,
        if (imamAddressLng != null) 'imamAddressLng': imamAddressLng,
        if (mohaffezPhone != null) 'mohaffezPhone': mohaffezPhone,
        if (planType != null) 'planType': planType,
        if (planId != null) 'planId': planId,
        if (planTitle != null) 'planTitle': planTitle,
        if (sessionsCount != null) 'sessionsCount': sessionsCount,
        if (validityDays != null) 'validityDays': validityDays,
        if (studentCountryCode != null)
          'studentCountryCode': studentCountryCode,
        if (studentCountryName != null)
          'studentCountryName': studentCountryName,
        if (displayCurrencyCode != null)
          'displayCurrencyCode': displayCurrencyCode,
        if (displayCurrencyLabel != null)
          'displayCurrencyLabel': displayCurrencyLabel,
        if (displayAmount != null) 'displayAmount': displayAmount,
        if (fxRateToEGP != null) 'fxRateToEGP': fxRateToEGP,
        if (chargedAmountEGP != null) 'chargedAmountEGP': chargedAmountEGP,
        if (sessionDurationMinutes != null)
          'sessionDurationMinutes': sessionDurationMinutes,
      });

      if (kDebugMode) {
        debugPrint('✅ [DirectPaymentService] studentMarkPaid returned: '
            '${result.data}');
      }

      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DirectPaymentService] studentMarkPaid error: '
            'code=${e.code}, message=${e.message}');
      }
      // Idempotent — already submitted, treat as success
      if (e.code == 'already-exists') {
        try {
          final msg = e.message ?? '{}';
          final parsed = Map<String, dynamic>.from(
            msg.startsWith('{') ? _parseJson(msg) : {'success': true},
          );
          return parsed;
        } catch (_) {
          return {'success': true, 'message': e.message};
        }
      }
      rethrow;
    }
  }

  // ── Mohaffez: confirm single-session payment received ────────────────────
// lib/services/directpaymentservice.dart

  static Future<Map<String, dynamic>> mohaffezConfirm(
      String directPaymentRequestId) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable(
        'mohaffezConfirmDirectPayment',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      )
          .call({'directPaymentRequestId': directPaymentRequestId});

      if (result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      }
      return {'success': true};
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint(
            'DirectPaymentService mohaffezConfirm: code=${e.code}, message=${e.message}');
      }
      if (e.code == 'already-exists') {
        return {'success': true, 'message': e.message};
      }
      rethrow;
    }
  }

  // ── Mohaffez: confirm bundle/subscription payment ────────────────────────
  // WHY: CF reads ALL plan/slot/student fields directly from the
  // directPaymentRequests doc — the client only passes the paymentId.
  // This prevents the mohaffez from manipulating plan data on confirmation.
  static Future<void> mohaffezConfirmBundlePayment({
    required String paymentId,
  }) async {
    try {
      await _functions
          .httpsCallable(
        'confirmBundleDirectPayment',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      )
          .call({'paymentId': paymentId});
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DirectPaymentService] mohaffezConfirmBundlePayment: '
            'code=${e.code}, message=${e.message}');
      }
      if (e.code == 'already-exists') return; // idempotent — already confirmed
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

  // ── Stream: pending confirmations for mohaffez ───────────────────────────
  static Stream<List<DirectPaymentModel>> watchPendingConfirmations(
      String mohaffezId) {
    return _db
        .collection('directPaymentRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pendingconfirmation')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => DirectPaymentModel.fromFirestore(d)).toList());
  }

  // ── Stream: single direct payment request by ID ──────────────────────────
  static Stream<DirectPaymentModel?> watchDirectPayment(
      String directPaymentRequestId) {
    return _db
        .collection('directPaymentRequests')
        .doc(directPaymentRequestId)
        .snapshots()
        .map((s) => s.exists ? DirectPaymentModel.fromFirestore(s) : null);
  }

  // ── Fetch admin wallet numbers ────────────────────────────────────────────
  static Future<Map<String, String?>> getAdminWalletNumbers() async {
    final doc = await _db.collection('systemConfig').doc('global').get();
    final data = doc.data() ?? {};
    final wallets = data['adminWallets'] as Map<String, dynamic>? ?? {};
    return {
      'instapay': wallets['instapay'] as String?,
      'vodafonecash': wallets['vodafonecash'] as String?,
      'orangemoney': wallets['orangemoney'] as String?,
    };
  }

  // ── Simple JSON parser for error messages ────────────────────────────────
  // Minimal: handles {"success":true,"message":"..."} only
  static Map<String, dynamic> _parseJson(String s) {
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
