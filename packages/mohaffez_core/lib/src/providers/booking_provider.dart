// lib/providers/booking_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking_result.dart';

final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService();
});

final legacyBookingFlowProvider =
    StateNotifierProvider<LegacyBookingFlowNotifier, LegacyBookingState>((ref) {
  return LegacyBookingFlowNotifier(ref.read(bookingServiceProvider));
});

enum BookingPaymentMethod {
  bundleCredit,
  payAfterAcceptance,
  buyNewPackage,
  freeSession,
  directPayment,
}

extension BookingPaymentMethodValue on BookingPaymentMethod {
  String get value {
    switch (this) {
      case BookingPaymentMethod.bundleCredit:
        return 'bundle_credit';
      case BookingPaymentMethod.payAfterAcceptance:
        return 'pay_after_acceptance';
      case BookingPaymentMethod.buyNewPackage:
        return 'buy_new_package';
      case BookingPaymentMethod.freeSession:
        return 'free_session';
      case BookingPaymentMethod.directPayment:
        // ── FIX: CF checks selectedPaymentMethod === 'directpayment'
        // (no underscore). The previous value 'direct_payment' never
        // matched, so createSessionRequest always wrote status: 'pending'
        // instead of 'awaitingpayment', forcing the orphan-recovery path
        // on every single direct-payment booking.
        return 'directpayment'; // ← was: 'direct_payment'
    }
  }
}

class LegacyBookingState {
  final BookingPaymentMethod? selectedPaymentMethod;
  final bool isSubmitting;
  final bool isSuccess;
  final String? sessionId;
  final String? error;

  const LegacyBookingState({
    this.selectedPaymentMethod,
    this.isSubmitting = false,
    this.isSuccess = false,
    this.sessionId,
    this.error,
  });

  LegacyBookingState copyWith({
    BookingPaymentMethod? selectedPaymentMethod,
    bool clearSelectedPaymentMethod = false,
    bool? isSubmitting,
    bool? isSuccess,
    String? sessionId,
    Object? error = _kSentinel,
  }) {
    return LegacyBookingState(
      selectedPaymentMethod: clearSelectedPaymentMethod
          ? null
          : selectedPaymentMethod ?? this.selectedPaymentMethod,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      sessionId: sessionId ?? this.sessionId,
      error: error == _kSentinel ? this.error : error as String?,
    );
  }
}

const Object _kSentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class LegacyBookingFlowNotifier extends StateNotifier<LegacyBookingState> {
  LegacyBookingFlowNotifier(this._bookingService)
      : super(const LegacyBookingState());

  final BookingService _bookingService;

  void setSelectedPaymentMethod(BookingPaymentMethod method) {
    state = state.copyWith(selectedPaymentMethod: method);
  }

  void clearSelectedPaymentMethod() {
    state = state.copyWith(clearSelectedPaymentMethod: true);
  }

  // ── Free Session ───────────────────────────────────────────────────────────

  Future<BookingResult> createFreeSession({
    required String mohaffezId,
    required String mohaffezName,
    required String studentId,
    required String studentName,
    required String sessionType,
    required String preferredTimeSlot,
    required DateTime slotDate,
    required DateTime slotStart,
    required DateTime slotEnd,
    String? imamAddressText,
    double? imamAddressLat,
    double? imamAddressLng,
    String? mohaffezPhone,
    required String promoCode,
    String? requestId,
    String? paymentId,
    String? guardianId,
    String? guardianName,
    String? studentProfileId,
    String? studentProfileName,
    String? studentProfileGender,
    DateTime? studentProfileBirthDate,
    int? studentAge,
    int? sessionDurationMinutes,
    int bookingTimeZoneVersion = 0,
    String? scheduleTimeZoneId,
    String? teacherLocalDate,
    String? teacherLocalTimeSlot,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final result = await _bookingService.createFreeSession(
        mohaffezId: mohaffezId,
        mohaffezName: mohaffezName,
        studentId: studentId,
        studentName: studentName,
        sessionType: sessionType,
        preferredTimeSlot: preferredTimeSlot,
        slotDate: slotDate,
        slotStart: slotStart,
        slotEnd: slotEnd,
        imamAddressText: imamAddressText,
        imamAddressLat: imamAddressLat,
        imamAddressLng: imamAddressLng,
        mohaffezPhone: mohaffezPhone,
        promoCode: promoCode,
        requestId: requestId,
        paymentId: paymentId,
        guardianId: guardianId,
        guardianName: guardianName,
        studentProfileId: studentProfileId,
        studentProfileName: studentProfileName,
        studentProfileGender: studentProfileGender,
        studentProfileBirthDate: studentProfileBirthDate,
        studentAge: studentAge,
        sessionDurationMinutes: sessionDurationMinutes,
        bookingTimeZoneVersion: bookingTimeZoneVersion,
        scheduleTimeZoneId: scheduleTimeZoneId,
        teacherLocalDate: teacherLocalDate,
        teacherLocalTimeSlot: teacherLocalTimeSlot,
      );

      if (result.isSuccess) {
        state = state.copyWith(
          isSubmitting: false,
          isSuccess: true,
          sessionId: result.sessionId,
          error: null,
        );
      } else {
        state = state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          error: result.errorMessage,
        );
      }

      return result;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('❌ [createFreeSession] Unexpected error: $e');
      if (kDebugMode) debugPrintStack(stackTrace: stack);
      const msg = 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى';
      state = state.copyWith(isSubmitting: false, isSuccess: false, error: msg);
      return BookingResult.failure(msg);
    }
  }

  // ── Session Request ────────────────────────────────────────────────────────

  Future<BookingResult> createSessionRequest({
    required String mohaffezId,
    required String studentId,
    required String studentName,
    required String mohaffezName,
    required String sessionType,
    required String preferredTimeSlot,
    required DateTime slotStart,
    required DateTime slotEnd,
    DateTime? slotDate,
    String? imamAddressText,
    double? imamAddressLat,
    double? imamAddressLng,
    String? mohaffezPhone,
    String? studentPhone,
    String? subscriptionId,
    bool isPaid = false,
    bool requiresPaymentOnAcceptance = false,
    BookingPaymentMethod? paymentMethod,
    String? slotLockId,
    String? planId,
    String? planTitle,
    double? paymentAmount,
    int? sessionsCount,
    String? planType,
    String? preferredProvider,
    String? guardianId,
    String? guardianName,
    String? studentProfileId,
    String? studentProfileName,
    String? studentProfileGender,
    DateTime? studentProfileBirthDate,
    int? studentAge,
    int? sessionDurationMinutes,
    int bookingTimeZoneVersion = 0,
    String? scheduleTimeZoneId,
    String? teacherLocalDate,
    String? teacherLocalTimeSlot,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final selectedMethod = paymentMethod ?? state.selectedPaymentMethod;
      final method = selectedMethod ?? BookingPaymentMethod.payAfterAcceptance;
      final methodRequiresPayment =
          method == BookingPaymentMethod.payAfterAcceptance;
      final methodSubscriptionId =
          method == BookingPaymentMethod.bundleCredit ? subscriptionId : null;

      final result = await _bookingService.createSessionRequest(
        mohaffezId: mohaffezId,
        studentId: studentId,
        studentName: studentName,
        mohaffezName: mohaffezName,
        sessionType: sessionType,
        preferredTimeSlot: preferredTimeSlot,
        slotStart: slotStart,
        slotEnd: slotEnd,
        slotDate: slotDate,
        imamAddressText: imamAddressText,
        imamAddressLat: imamAddressLat,
        imamAddressLng: imamAddressLng,
        mohaffezPhone: mohaffezPhone,
        studentPhone: studentPhone,
        subscriptionId: methodSubscriptionId,
        isPaid: isPaid,
        requiresPaymentOnAcceptance:
            requiresPaymentOnAcceptance || methodRequiresPayment,
        paymentMethod: method,
        slotLockId: slotLockId,
        planId: planId,
        planTitle: planTitle,
        paymentAmount: paymentAmount,
        sessionsCount: sessionsCount,
        planType: planType,
        preferredProvider: preferredProvider,
        guardianId: guardianId,
        guardianName: guardianName,
        studentProfileId: studentProfileId,
        studentProfileName: studentProfileName,
        studentProfileGender: studentProfileGender,
        studentProfileBirthDate: studentProfileBirthDate,
        studentAge: studentAge,
        sessionDurationMinutes: sessionDurationMinutes,
        bookingTimeZoneVersion: bookingTimeZoneVersion,
        scheduleTimeZoneId: scheduleTimeZoneId,
        teacherLocalDate: teacherLocalDate,
        teacherLocalTimeSlot: teacherLocalTimeSlot,
      );

      if (result.isSuccess) {
        state = state.copyWith(
          isSubmitting: false,
          isSuccess: true,
          sessionId: result.sessionId,
          error: null,
        );
        clearSelectedPaymentMethod();
      } else {
        state = state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          error: result.errorMessage,
        );
      }

      return result;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ [createSessionRequest] Unexpected error: $e');
        debugPrintStack(stackTrace: stack);
      }
      const msg = 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى';
      state = state.copyWith(isSubmitting: false, isSuccess: false, error: msg);
      return BookingResult.failure(msg);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLOT LOCK RESULT
// ─────────────────────────────────────────────────────────────────────────────

class SlotLockResult {
  final bool success;
  final String? lockId;
  final String? availabilityDocId;
  final String? error;

  const SlotLockResult({
    required this.success,
    this.lockId,
    this.availabilityDocId,
    this.error,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> _ensureAuthenticatedForCallable(String flowLabel) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode)
        debugPrint('❌ [$flowLabel] No Firebase user is signed in.');
      return 'يجب تسجيل الدخول أولاً';
    }

    try {
      final token = await user.getIdToken(false);
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ [$flowLabel] Refreshed Firebase ID token is empty.');
        }
        return 'تعذر التحقق من تسجيل الدخول. حاول تسجيل الخروج ثم الدخول مرة أخرى';
      }
      if (kDebugMode) debugPrint('✅ [$flowLabel] Auth ready. uid=${user.uid}');
      return null;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ [$flowLabel] Failed to refresh Firebase ID token: $e');
        debugPrintStack(stackTrace: stack);
      }
      return 'تعذر التحقق من تسجيل الدخول. تحقق من الاتصال ثم حاول مرة أخرى';
    }
  }

  Future<void> _ensureAppCheckForCallable(String flowLabel) async {
    if (kDebugMode) return;
    try {
      final token = await FirebaseAppCheck.instance.getToken(false);
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              '⚠️ $flowLabel App Check token is null/empty (non-fatal).');
        }
      } else {
        if (kDebugMode) {
          debugPrint('✅ $flowLabel App Check token ready (cached).');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '⚠️ $flowLabel App Check token fetch failed (non-fatal): $e');
      }
    }
  }

  // ── Free Session ───────────────────────────────────────────────────────────

  Future<BookingResult> createFreeSession({
    required String mohaffezId,
    required String mohaffezName,
    required String studentId,
    required String studentName,
    required String sessionType,
    required String preferredTimeSlot,
    required DateTime slotDate,
    required DateTime slotStart,
    required DateTime slotEnd,
    String? imamAddressText,
    double? imamAddressLat,
    double? imamAddressLng,
    String? mohaffezPhone,
    required String promoCode,
    String? requestId,
    String? paymentId,
    String? guardianId,
    String? guardianName,
    String? studentProfileId,
    String? studentProfileName,
    String? studentProfileGender,
    DateTime? studentProfileBirthDate,
    int? studentAge,
    int? sessionDurationMinutes,
    int bookingTimeZoneVersion = 0,
    String? scheduleTimeZoneId,
    String? teacherLocalDate,
    String? teacherLocalTimeSlot,
  }) async {
    try {
      final authError = await _ensureAuthenticatedForCallable('FREE SESSION');
      if (authError != null) {
        return BookingResult.failure(authError);
      }

      await _ensureAppCheckForCallable('FREE SESSION');

      if (kDebugMode) {
        debugPrint('🔄 [FREE SESSION] Starting Cloud Function call...');
        debugPrint('📍 Function: confirmFreeSession');
        debugPrint('👤 Student: $studentId');
        debugPrint('👨‍🏫 Mohaffez: $mohaffezId');
        debugPrint('🎟️ Promo: $promoCode');
        debugPrint('🔑 RequestId: $requestId');
      }

      final callable = FirebaseFunctions.instance.httpsCallable(
        'confirmFreeSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final data = {
        'mohaffezId': mohaffezId,
        'mohaffezName': mohaffezName,
        'studentId': studentId,
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
        if (sessionDurationMinutes != null)
          'sessionDurationMinutes': sessionDurationMinutes,
        if (bookingTimeZoneVersion == 1) ...{
          'bookingTimeZoneVersion': 1,
          'slotStartUtc': slotStart.toUtc().toIso8601String(),
          'slotEndUtc': slotEnd.toUtc().toIso8601String(),
          if (scheduleTimeZoneId != null)
            'scheduleTimeZoneId': scheduleTimeZoneId,
          if (teacherLocalDate != null) 'teacherLocalDate': teacherLocalDate,
          if (teacherLocalTimeSlot != null)
            'teacherLocalTimeSlot': teacherLocalTimeSlot,
        },
        'sessionType': sessionType,
        'preferredTimeSlot': preferredTimeSlot,
        'slotDate': slotDate.toUtc().toIso8601String(),
        'slotStart': slotStart.toUtc().toIso8601String(),
        'slotEnd': slotEnd.toUtc().toIso8601String(),
        'imamAddressText': imamAddressText,
        'imamAddressLat': imamAddressLat,
        'imamAddressLng': imamAddressLng,
        'mohaffezPhone': mohaffezPhone,
        'promoCode': promoCode,
        if (requestId != null) 'requestId': requestId,
        if (paymentId != null) 'paymentId': paymentId,
      };

      if (kDebugMode) debugPrint('📦 Payload keys: ${data.keys.join(', ')}');

      final result = await callable.call(data);

      if (kDebugMode) {
        debugPrint('✅ [FREE SESSION] Response received');
        debugPrint('📄 Response: ${result.data}');
      }

      if (result.data is! Map) {
        return BookingResult.failure('استجابة غير متوقعة من الخادم');
      }

      final responseMap = Map<String, dynamic>.from(result.data as Map);

      if (responseMap['success'] == true) {
        final sessionId = responseMap['sessionId'] as String?;
        if (sessionId != null && sessionId.isNotEmpty) {
          if (kDebugMode) debugPrint('🎉 Free session created: $sessionId');
          return BookingResult.success(sessionId);
        }
        if (kDebugMode) debugPrint('⚠️ Success but no sessionId returned');
        return BookingResult.failure('تم الحجز ولكن لم يتم إرجاع معرف الجلسة');
      }

      final errorMsg =
          responseMap['message'] as String? ?? 'فشل في إنشاء الجلسة';
      if (kDebugMode) debugPrint('❌ Cloud Function failure: $errorMsg');
      return BookingResult.failure(errorMsg);
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FREE SESSION] FirebaseFunctionsException');
        debugPrint('   Code: ${e.code}');
        debugPrint('   Message: ${e.message}');
        debugPrint('   Details: ${e.details}');
      }

      final String errorMessage;
      switch (e.code) {
        case 'unauthenticated':
          errorMessage = 'يجب تسجيل الدخول أولاً';
          break;
        case 'invalid-argument':
          errorMessage = 'بيانات غير مكتملة';
          break;
        case 'not-found':
          errorMessage = 'كود الخصم غير صحيح';
          break;
        case 'already-exists':
          errorMessage = e.message ??
              'لقد استخدمت كود الخصم من قبل، ولا يمكن استخدامه أكثر من مرة.';
          break;
        case 'failed-precondition':
          errorMessage = e.message ?? 'لا يمكن إتمام العملية في الوقت الحالي';
          break;
        case 'deadline-exceeded':
          errorMessage = 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى';
          break;
        case 'unavailable':
          errorMessage = 'الخدمة غير متاحة حالياً. يرجى المحاولة لاحقاً';
          break;
        default:
          errorMessage = 'حدث خطأ. يرجى المحاولة مرة أخرى';
      }

      return BookingResult.failure(errorMessage);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [FREE SESSION] Unexpected error: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
      return BookingResult.failure('حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى');
    }
  }

  // ── Session Request ────────────────────────────────────────────────────────

  Future<BookingResult> createSessionRequest({
    required String mohaffezId,
    required String studentId,
    required String studentName,
    required String mohaffezName,
    required String sessionType,
    required String preferredTimeSlot,
    required DateTime slotStart,
    required DateTime slotEnd,
    DateTime? slotDate,
    String? imamAddressText,
    double? imamAddressLat,
    double? imamAddressLng,
    String? mohaffezPhone,
    String? studentPhone,
    String? subscriptionId,
    bool isPaid = false,
    bool requiresPaymentOnAcceptance = false,
    BookingPaymentMethod? paymentMethod,
    String? slotLockId,
    String? planId,
    String? planTitle,
    double? paymentAmount,
    int? sessionsCount,
    String? planType,
    String? preferredProvider,
    String? guardianId,
    String? guardianName,
    String? studentProfileId,
    String? studentProfileName,
    String? studentProfileGender,
    DateTime? studentProfileBirthDate,
    int? studentAge,
    int? sessionDurationMinutes,
    int bookingTimeZoneVersion = 0,
    String? scheduleTimeZoneId,
    String? teacherLocalDate,
    String? teacherLocalTimeSlot,
  }) async {
    final SlotLockResult? lockResult = slotLockId != null
        ? SlotLockResult(success: true, lockId: slotLockId)
        : null;

    try {
      final authError =
          await _ensureAuthenticatedForCallable('SESSION REQUEST');
      if (authError != null) {
        if (lockResult?.success == true) {
          await _releaseSlotLock(lockResult!).catchError((e) {
            if (kDebugMode) {
              debugPrint('⚠️ [SESSION REQUEST] Failed to release lock: $e');
            }
          });
        }
        return BookingResult.failure(authError);
      }

      await _ensureAppCheckForCallable('SESSION REQUEST');

      final DateTime actualSlotDate =
          slotDate ?? DateTime(slotStart.year, slotStart.month, slotStart.day);

      if (kDebugMode) {
        debugPrint('🔄 [SESSION REQUEST] Calling createSessionRequest CF...');
        debugPrint('   mohaffezId: $mohaffezId');
        debugPrint('   studentId: $studentId');
        debugPrint('   slotLockId: $slotLockId');
        debugPrint(
            '   selectedPaymentMethod: ${(paymentMethod ?? BookingPaymentMethod.payAfterAcceptance).value}');
      }

      final callable = FirebaseFunctions.instance.httpsCallable(
        'createSessionRequest',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call({
        'mohaffezId': mohaffezId,
        'studentId': studentId,
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
        'mohaffezName': mohaffezName,
        'sessionType': sessionType,
        if (sessionType == 'online' && preferredProvider != null)
          'preferredProvider': preferredProvider,
        'preferredTimeSlot': preferredTimeSlot,
        'slotDate': actualSlotDate.toUtc().toIso8601String(),
        'slotStart': slotStart.toUtc().toIso8601String(),
        'slotEnd': slotEnd.toUtc().toIso8601String(),
        'imamAddressText': imamAddressText,
        'imamAddressLat': imamAddressLat,
        'imamAddressLng': imamAddressLng,
        'mohaffezPhone': mohaffezPhone,
        if (studentPhone != null && studentPhone.trim().isNotEmpty)
          'studentPhone': studentPhone.trim(),
        'subscriptionId': subscriptionId,
        'requiresPaymentOnAcceptance': requiresPaymentOnAcceptance,
        // ── Value is always a plain string via the .value extension ─────────
        // e.g. BookingPaymentMethod.directPayment → 'directpayment'
        //      BookingPaymentMethod.payAfterAcceptance → 'pay_after_acceptance'
        'selectedPaymentMethod':
            (paymentMethod ?? BookingPaymentMethod.payAfterAcceptance).value,
        'planId': planId,
        'planTitle': planTitle,
        'paymentAmount': paymentAmount,
        'sessionsCount': sessionsCount,
        'planType': planType,
        if (sessionDurationMinutes != null)
          'sessionDurationMinutes': sessionDurationMinutes,
        if (bookingTimeZoneVersion == 1) ...{
          'bookingTimeZoneVersion': 1,
          'slotStartUtc': slotStart.toUtc().toIso8601String(),
          'slotEndUtc': slotEnd.toUtc().toIso8601String(),
          if (scheduleTimeZoneId != null)
            'scheduleTimeZoneId': scheduleTimeZoneId,
          if (teacherLocalDate != null) 'teacherLocalDate': teacherLocalDate,
          if (teacherLocalTimeSlot != null)
            'teacherLocalTimeSlot': teacherLocalTimeSlot,
        },
        if (lockResult?.lockId != null) 'slotLockId': lockResult!.lockId,
      });

      if (kDebugMode) {
        debugPrint('✅ [SESSION REQUEST] Response: ${result.data}');
      }

      if (result.data is! Map) {
        if (kDebugMode) {
          debugPrint(
              '❌ [SESSION REQUEST] Unexpected response shape: ${result.data}');
        }
        return BookingResult.failure('استجابة غير متوقعة من الخادم');
      }

      final responseMap = Map<String, dynamic>.from(result.data as Map);

      if (responseMap['success'] == true) {
        final requestId = responseMap['requestId'] as String?;
        final isDuplicate = responseMap['isDuplicate'] == true;
        if (kDebugMode) {
          debugPrint(isDuplicate
              ? '⚠️ Session request already exists: $requestId'
              : '🎉 Session request created: $requestId');
        }
        return BookingResult.success(
          requestId ?? '',
          isDuplicate: isDuplicate,
        );
      }

      final errorMsg =
          responseMap['message'] as String? ?? 'فشل في إنشاء طلب الجلسة';
      if (kDebugMode) {
        debugPrint('❌ [SESSION REQUEST] CF returned failure: $errorMsg');
      }
      return BookingResult.failure(errorMsg);
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SESSION REQUEST] FirebaseFunctionsException');
        debugPrint('   Code: ${e.code}');
        debugPrint('   Message: ${e.message}');
      }

      if (lockResult?.success == true) {
        await _releaseSlotLock(lockResult!).catchError((e) {
          if (kDebugMode) {
            debugPrint('⚠️ [SESSION REQUEST] Failed to release lock: $e');
          }
        });
      }

      final String errorMessage;
      switch (e.code) {
        case 'unauthenticated':
          errorMessage = 'يجب تسجيل الدخول أولاً';
          break;
        case 'invalid-argument':
          errorMessage = 'بيانات غير مكتملة';
          break;
        case 'not-found':
          errorMessage = 'الطلب غير موجود';
          break;
        case 'failed-precondition':
          errorMessage = 'لا يمكن إتمام الحجز. يرجى المحاولة مرة أخرى';
          break;
        case 'resource-exhausted':
          errorMessage = 'هذا الموعد محجوز بالفعل. يرجى اختيار موعد آخر';
          break;
        case 'deadline-exceeded':
          errorMessage = 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى';
          break;
        case 'unavailable':
          errorMessage = 'الخدمة غير متاحة حالياً. يرجى المحاولة لاحقاً';
          break;
        default:
          errorMessage = 'حدث خطأ. يرجى المحاولة مرة أخرى';
      }

      return BookingResult.failure(errorMessage);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ [SESSION REQUEST] Unexpected error: $e');
        debugPrintStack(stackTrace: stack);
      }

      if (lockResult?.success == true) {
        await _releaseSlotLock(lockResult!).catchError((releaseErr) {
          if (kDebugMode) {
            debugPrint(
                '⚠️ [SESSION REQUEST] Lock release also failed: $releaseErr');
          }
        });
      }

      return BookingResult.failure('حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى');
    }
  }

  Future<void> _releaseSlotLock(SlotLockResult lockResult) async {
    if (lockResult.lockId == null) return;

    final lockRef = _firestore.collection('slotLocks').doc(lockResult.lockId);
    final lockDoc = await lockRef.get();
    if (!lockDoc.exists) return;

    final lockData = lockDoc.data()!;
    final mohaffezId = lockData['mohaffezId'] as String?;
    final availabilityDocId = lockData['availabilityDocId'] as String?;
    final timeSlot = lockData['timeSlot'] as String?;
    final sessionType = lockData['sessionType'] as String?;

    if (mohaffezId == null ||
        availabilityDocId == null ||
        timeSlot == null ||
        sessionType == null) {
      await lockRef.delete();
      return;
    }

    final availabilityRef = _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('availability')
        .doc(availabilityDocId);

    final selectedSlot = _normalizeTimeSlot(timeSlot);

    await _firestore.runTransaction((transaction) async {
      final availabilityDoc = await transaction.get(availabilityRef);
      if (!availabilityDoc.exists) {
        transaction.delete(lockRef);
        return;
      }

      final data = availabilityDoc.data() ?? <String, dynamic>{};
      final timeSlots =
          List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);

      var changed = false;
      for (var i = 0; i < timeSlots.length; i++) {
        final slot = timeSlots[i];
        final slotTime =
            _normalizeTimeSlot('${slot['startTime']}-${slot['endTime']}');
        if (slotTime == selectedSlot &&
            slot['sessionType'] == sessionType &&
            slot['lockId'] == lockResult.lockId) {
          final updated = Map<String, dynamic>.from(slot)
            ..remove('lockedBy')
            ..remove('lockId')
            ..remove('lockedAt');
          timeSlots[i] = updated;
          changed = true;
          break;
        }
      }

      if (changed) {
        transaction.update(availabilityRef, {
          'timeSlots': timeSlots,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.delete(lockRef);
    });
  }

  // ── Cancel Session Request ─────────────────────────────────────────────────

  Future<BookingResult> cancelSessionRequest(String requestId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final requestRef =
            _firestore.collection('sessionRequests').doc(requestId);
        final requestSnap = await transaction.get(requestRef);

        if (!requestSnap.exists) {
          throw Exception('الطلب غير موجود');
        }

        final requestData = requestSnap.data()!;
        final status = requestData['status'] as String? ?? 'pending';

        if (status == 'cancelled') {
          return;
        }

        if (status == 'completed') {
          throw Exception('Cannot cancel completed session');
        }

        final slotLockId = requestData['slotLockId'] as String?;
        final mohaffezId = requestData['mohaffezId'] as String?;
        final slotDate = requestData['slotDate'] as Timestamp?;
        final timeSlot = requestData['preferredTimeSlot'] as String?;
        final sessionType = requestData['sessionType'] as String?;

        DocumentReference<Map<String, dynamic>>? availRef;
        DocumentSnapshot<Map<String, dynamic>>? availSnap;
        if (mohaffezId != null &&
            slotDate != null &&
            timeSlot != null &&
            sessionType != null) {
          availRef = await _findAvailabilityRefTransaction(
            transaction: transaction,
            mohaffezId: mohaffezId,
            slotDate: slotDate,
          );
          if (availRef != null) {
            availSnap = await transaction.get(availRef);
          }
        }

        transaction.update(requestRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'student',
        });

        if (slotLockId != null && slotLockId.trim().isNotEmpty) {
          final lockRef = _firestore.collection('slotLocks').doc(slotLockId);
          transaction.delete(lockRef);
        }

        if (availRef != null &&
            availSnap != null &&
            availSnap.exists &&
            timeSlot != null &&
            sessionType != null) {
          final availData = availSnap.data();
          if (availData != null) {
            final updated =
                _computeRestoredSlots(availData, timeSlot, sessionType);
            if (updated != null) {
              transaction.update(availRef, {
                'timeSlots': updated,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      });

      return BookingResult.success(requestId);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ [cancelSessionRequest] Error: $e');
        debugPrintStack(stackTrace: stack);
      }
      return BookingResult.failure('حدث خطأ. يرجى المحاولة مرة أخرى');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  // ── BUG-5 FIX: Also strip en-dash (U+2013) and em-dash (U+2014) to match
  // the Cloud Function normalizeTimeSlot() behaviour. Without this, a slot
  // whose display label contains an en-dash could fail the equality check
  // during lock release or slot restore, leaving the slot disabled.
  String _normalizeTimeSlot(String raw) => raw
      .replaceAll(' ', '')
      .replaceAll('\u2013', '-') // en-dash → hyphen
      .replaceAll('\u2014', '-'); // em-dash → hyphen

  // FIX Bug 1: Was using `slotDateObj.weekday == 7 ? 7 : slotDateObj.weekday + 1`
  // which shifted Mon→2, Tue→3 ... Sat→7, Sun→7 — making Sunday and Saturday
  // indistinguishable and shifting every other day by +1.
  // Every other place in the codebase (SessionRepository, SessionActionsNotifier)
  // uses `.weekday` directly. This mismatch meant student cancellations silently
  // failed to restore the availability slot for any day Mon–Sat.
  Future<DocumentReference<Map<String, dynamic>>?>
      _findAvailabilityRefTransaction({
    required Transaction transaction,
    required String mohaffezId,
    required Timestamp slotDate,
  }) async {
    final slotDateObj = slotDate.toDate();
    final dayOfWeek =
        slotDateObj.weekday; // FIX: was weekday == 7 ? 7 : weekday + 1

    final availQuery = _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('availability')
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .limit(1);

    final availSnap = await availQuery.get();
    if (availSnap.docs.isEmpty) return null;
    return availSnap.docs.first.reference;
  }

  List<Map<String, dynamic>>? _computeRestoredSlots(
    Map<String, dynamic> availabilityData,
    String timeSlot,
    String sessionType,
  ) {
    final timeSlots =
        List<Map<String, dynamic>>.from(availabilityData['timeSlots'] ?? []);
    final normalizedSelected = _normalizeTimeSlot(timeSlot);
    var restored = false;
    for (final slot in timeSlots) {
      final slotTime =
          _normalizeTimeSlot('${slot['startTime']}-${slot['endTime']}');
      if (slotTime == normalizedSelected &&
          slot['sessionType'] == sessionType) {
        slot.remove('lockedBy');
        slot.remove('lockId');
        slot.remove('lockedAt');
        slot['enabled'] = true;
        restored = true;
        break;
      }
    }
    return restored ? timeSlots : null;
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getStudentRequests(String studentId) {
    return _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: [
          'pending',
          'awaitingpayment',
          'awaitingdirectpaymentconfirmation',
          'rejected',
          'cancelled',
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {...data, 'id': doc.id};
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> getMohaffezRequests(String mohaffezId) {
    return _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', whereIn: [
          'pending',
          'awaitingpayment',
          'awaitingdirectpaymentconfirmation',
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
            .toList());
  }
}
