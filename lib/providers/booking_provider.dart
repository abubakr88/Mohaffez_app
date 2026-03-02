// lib/providers/booking_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking_result.dart';

final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService();
});

final bookingFlowProvider =
    StateNotifierProvider<BookingFlowNotifier, BookingState>((ref) {
  return BookingFlowNotifier(ref.read(bookingServiceProvider));
});

enum BookingPaymentMethod {
  subscriptionCredit,
  payAfterAcceptance,
  buyNewPackage,
  freeSession,
}

extension BookingPaymentMethodValue on BookingPaymentMethod {
  String get value {
    switch (this) {
      case BookingPaymentMethod.subscriptionCredit:
        return 'subscription_credit';
      case BookingPaymentMethod.payAfterAcceptance:
        return 'pay_after_acceptance';
      case BookingPaymentMethod.buyNewPackage:
        return 'buy_new_package';
      case BookingPaymentMethod.freeSession:
        return 'free_session';
    }
  }
}

class BookingState {
  final BookingPaymentMethod? selectedPaymentMethod;
  final bool isSubmitting;
  final bool isSuccess;
  final String? sessionId;
  final String? error;

  const BookingState({
    this.selectedPaymentMethod,
    this.isSubmitting = false,
    this.isSuccess = false,
    this.sessionId,
    this.error,
  });

  BookingState copyWith({
    BookingPaymentMethod? selectedPaymentMethod,
    bool clearSelectedPaymentMethod = false,
    bool? isSubmitting,
    bool? isSuccess,
    String? sessionId,
    // FIX: Allow explicitly setting error to null by using a sentinel pattern
    Object? error = _kSentinel,
  }) {
    return BookingState(
      selectedPaymentMethod: clearSelectedPaymentMethod
          ? null
          : selectedPaymentMethod ?? this.selectedPaymentMethod,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      sessionId: sessionId ?? this.sessionId,
      // FIX: If caller passed error: null explicitly, use null; otherwise keep existing
      error: error == _kSentinel ? this.error : error as String?,
    );
  }
}

// Sentinel to distinguish "not passed" from "explicitly null" in copyWith
const Object _kSentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class BookingFlowNotifier extends StateNotifier<BookingState> {
  BookingFlowNotifier(this._bookingService) : super(const BookingState());

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
  }) async {
    // Clear previous error on new attempt
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
      debugPrint('❌ [createFreeSession] Unexpected error: $e');
      debugPrintStack(stackTrace: stack);
      state = state.copyWith(
        isSubmitting: false,
        isSuccess: false,
        error: e.toString(),
      );
      return BookingResult.failure(e.toString());
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
  }) async {
    // FIX BUG #1 + #2: Clear error on new attempt; do NOT use a bare `finally`
    // that only resets isSubmitting — it was masking all errors and never
    // setting isSuccess/error on the state, so the UI had no feedback.
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final selectedMethod = paymentMethod ?? state.selectedPaymentMethod;
      final method = selectedMethod ?? BookingPaymentMethod.payAfterAcceptance;
      final methodRequiresPayment =
          method == BookingPaymentMethod.payAfterAcceptance;
      final methodSubscriptionId =
          method == BookingPaymentMethod.subscriptionCredit
              ? subscriptionId
              : null;

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
      );

      // FIX BUG #1: Mirror createFreeSession — always write result into state
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
      // FIX BUG #1 (continued): Exceptions were caught but state was left with
      // isSubmitting: true because `finally` ran before the catch could set
      // the error. Now we handle everything in catch explicitly.
      debugPrint('❌ [createSessionRequest] Unexpected error: $e');
      debugPrintStack(stackTrace: stack);
      state = state.copyWith(
        isSubmitting: false,
        isSuccess: false,
        error: e.toString(),
      );
      return BookingResult.failure(e.toString());
    }
    // NOTE: `finally` block intentionally removed. A bare `finally` that only
    // calls state.copyWith(isSubmitting: false) will execute AFTER the catch
    // block but BEFORE its state write is observed by the UI on some Flutter
    // rebuild cycles, resulting in a flash of stale state.
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
      debugPrint('❌ [$flowLabel] No Firebase user is signed in.');
      return 'يجب تسجيل الدخول أولاً';
    }

    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        debugPrint('❌ [$flowLabel] Refreshed Firebase ID token is empty.');
        return 'تعذر التحقق من تسجيل الدخول. حاول تسجيل الخروج ثم الدخول مرة أخرى';
      }
      debugPrint('✅ [$flowLabel] Auth ready. uid=${user.uid}');
      return null;
    } catch (e, stack) {
      debugPrint('❌ [$flowLabel] Failed to refresh Firebase ID token: $e');
      debugPrintStack(stackTrace: stack);
      return 'تعذر التحقق من تسجيل الدخول. تحقق من الاتصال ثم حاول مرة أخرى';
    }
  }

  Future<String?> _ensureAppCheckForCallable(String flowLabel) async {
    try {
      final token = await FirebaseAppCheck.instance.getToken(true);
      if (token == null || token.isEmpty) {
        debugPrint('❌ [$flowLabel] App Check token is null/empty.');
        return 'تعذر التحقق من App Check. أعد تشغيل التطبيق ثم حاول مرة أخرى';
      }
      debugPrint('✅ [$flowLabel] App Check token ready.');
      return null;
    } catch (e, stack) {
      debugPrint('❌ [$flowLabel] Failed to get App Check token: $e');
      debugPrintStack(stackTrace: stack);
      return 'فشل التحقق من App Check. تحقق من إعداد Firebase Console';
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
  }) async {
    try {
      final authError = await _ensureAuthenticatedForCallable('FREE SESSION');
      if (authError != null) {
        return BookingResult.failure(authError);
      }
      final appCheckError = await _ensureAppCheckForCallable('FREE SESSION');
      if (appCheckError != null) {
        return BookingResult.failure(appCheckError);
      }

      debugPrint('🔄 [FREE SESSION] Starting Cloud Function call...');
      debugPrint('📍 Function: confirmFreeSession');
      debugPrint('👤 Student: $studentId');
      debugPrint('👨‍🏫 Mohaffez: $mohaffezId');
      debugPrint('🎟️ Promo: $promoCode');
      debugPrint('🔑 RequestId: $requestId');

      final callable = FirebaseFunctions.instance.httpsCallable(
        'confirmFreeSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final data = {
        // FIX-3: Send slot date-times as UTC ISO strings to avoid timezone drift in Cloud Functions
        'mohaffezId': mohaffezId,
        'mohaffezName': mohaffezName,
        'studentId': studentId,
        'studentName': studentName,
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

      debugPrint('📦 Payload keys: ${data.keys.join(', ')}');

      final result = await callable.call(data);

      debugPrint('✅ [FREE SESSION] Response received');
      debugPrint('📄 Response: ${result.data}');

      // FIX: Type-safe response parsing — original code could throw a cast
      // exception if data was not a Map, silently failing the whole flow.
      if (result.data is! Map) {
        return BookingResult.failure('استجابة غير متوقعة من الخادم');
      }

      final responseMap = Map<String, dynamic>.from(result.data as Map);

      if (responseMap['success'] == true) {
        final sessionId = responseMap['sessionId'] as String?;
        if (sessionId != null && sessionId.isNotEmpty) {
          debugPrint('🎉 Free session created: $sessionId');
          return BookingResult.success(sessionId);
        }
        debugPrint('⚠️ Success but no sessionId returned');
        return BookingResult.failure('تم الحجز ولكن لم يتم إرجاع معرف الجلسة');
      }

      final errorMsg =
          responseMap['message'] as String? ?? 'فشل في إنشاء الجلسة';
      debugPrint('❌ Cloud Function failure: $errorMsg');
      return BookingResult.failure(errorMsg);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [FREE SESSION] FirebaseFunctionsException');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Details: ${e.details}');

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
        case 'failed-precondition':
          errorMessage = e.message ?? 'لا يمكن إتمام العملية';
          break;
        case 'deadline-exceeded':
          errorMessage = 'انتهت مهلة الطلب. حاول مرة أخرى';
          break;
        case 'unavailable':
          errorMessage = 'الخدمة غير متاحة حالياً. حاول لاحقاً';
          break;
        default:
          errorMessage = e.message ?? 'حدث خطأ في النظام';
      }

      return BookingResult.failure(errorMessage);
    } catch (e, stackTrace) {
      debugPrint('❌ [FREE SESSION] Unexpected error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return BookingResult.failure('حدث خطأ غير متوقع: ${e.toString()}');
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
  }) async {
    // Pre-populate lockResult if slotLockId was already acquired by the caller
    final SlotLockResult? lockResult = slotLockId != null
        ? SlotLockResult(success: true, lockId: slotLockId)
        : null;

    try {
      final authError =
          await _ensureAuthenticatedForCallable('SESSION REQUEST');
      if (authError != null) {
        if (lockResult?.success == true) {
          await _releaseSlotLock(lockResult!).catchError((e) {
            debugPrint('⚠️ [SESSION REQUEST] Failed to release lock: $e');
          });
        }
        return BookingResult.failure(authError);
      }
      final appCheckError = await _ensureAppCheckForCallable('SESSION REQUEST');
      if (appCheckError != null) {
        if (lockResult?.success == true) {
          await _releaseSlotLock(lockResult!).catchError((e) {
            debugPrint('⚠️ [SESSION REQUEST] Failed to release lock: $e');
          });
        }
        return BookingResult.failure(appCheckError);
      }

      final DateTime actualSlotDate =
          slotDate ?? DateTime(slotStart.year, slotStart.month, slotStart.day);

      debugPrint('🔄 [SESSION REQUEST] Calling createSessionRequest CF...');
      debugPrint('   mohaffezId: $mohaffezId');
      debugPrint('   studentId: $studentId');
      debugPrint('   slotLockId: $slotLockId');
      final fallbackIdToken =
          await FirebaseAuth.instance.currentUser?.getIdToken();

      final callable = FirebaseFunctions.instance.httpsCallable(
        'createSessionRequest',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call({
        // FIX-3: Send slot date-times as UTC ISO strings to avoid timezone drift in Cloud Functions
        'mohaffezId': mohaffezId,
        'studentId': studentId,
        'studentName': studentName,
        'mohaffezName': mohaffezName,
        'sessionType': sessionType,
        'preferredTimeSlot': preferredTimeSlot,
        'slotDate': actualSlotDate.toUtc().toIso8601String(),
        'slotStart': slotStart.toUtc().toIso8601String(),
        'slotEnd': slotEnd.toUtc().toIso8601String(),
        'imamAddressText': imamAddressText,
        'imamAddressLat': imamAddressLat,
        'imamAddressLng': imamAddressLng,
        'mohaffezPhone': mohaffezPhone,
        'subscriptionId': subscriptionId,
        'requiresPaymentOnAcceptance': requiresPaymentOnAcceptance,
        'selectedPaymentMethod':
            (paymentMethod ?? BookingPaymentMethod.payAfterAcceptance).value,
        'planId': planId,
        'planTitle': planTitle,
        'paymentAmount': paymentAmount,
        'sessionsCount': sessionsCount,
        'planType': planType,
        if (fallbackIdToken != null) 'idToken': fallbackIdToken,
        if (lockResult?.lockId != null) 'slotLockId': lockResult!.lockId,
      });

      debugPrint('✅ [SESSION REQUEST] Response: ${result.data}');

      // FIX BUG #2 (service layer): Guard against non-Map response before
      // any field access. The original code did result.data['success'] directly,
      // which throws a NoSuchMethodError if data is null or not a Map — this
      // exception was silently caught, lock was released, and failure returned
      // without any useful context.
      if (result.data is! Map) {
        debugPrint(
            '❌ [SESSION REQUEST] Unexpected response shape: ${result.data}');
        return BookingResult.failure('استجابة غير متوقعة من الخادم');
      }

      final responseMap = Map<String, dynamic>.from(result.data as Map);

      if (responseMap['success'] == true) {
        // FIX: requestId may be null for some payment flows — don't hard-cast
        final requestId = responseMap['requestId'] as String?;
        debugPrint('🎉 Session request created: $requestId');
        return BookingResult.success(requestId ?? '');
      }

      final errorMsg =
          responseMap['message'] as String? ?? 'فشل في إنشاء طلب الجلسة';
      debugPrint('❌ [SESSION REQUEST] CF returned failure: $errorMsg');
      return BookingResult.failure(errorMsg);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [SESSION REQUEST] FirebaseFunctionsException');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');

      // FIX BUG #3: Release the slot lock on CF-level errors so the slot
      // doesn't stay locked indefinitely. The original catch was generic
      // and would release, but FirebaseFunctionsException was not caught
      // separately — it fell into the generic catch which DID call release,
      // but .catchError((_) {}) swallowed any release failures silently.
      if (lockResult?.success == true) {
        await _releaseSlotLock(lockResult!).catchError((e) {
          debugPrint('⚠️ [SESSION REQUEST] Failed to release lock: $e');
        });
      }

      final String errorMessage;
      switch (e.code) {
        case 'unauthenticated':
          errorMessage = 'يجب تسجيل الدخول أولاً';
          break;
        case 'invalid-argument':
          errorMessage = e.message ?? 'بيانات غير مكتملة';
          break;
        case 'not-found':
          errorMessage = 'الطلب غير موجود';
          break;
        case 'failed-precondition':
          // Covers: slot lock expired, slot already booked, slot disabled
          errorMessage =
              e.message ?? 'لا يمكن إتمام الحجز. الرجاء المحاولة مرة أخرى';
          break;
        case 'resource-exhausted':
          errorMessage = 'هذا الموعد محجوز بالفعل. الرجاء اختيار موعد آخر';
          break;
        case 'deadline-exceeded':
          errorMessage = 'انتهت مهلة الطلب. حاول مرة أخرى';
          break;
        case 'unavailable':
          errorMessage = 'الخدمة غير متاحة حالياً. حاول لاحقاً';
          break;
        default:
          errorMessage = e.message ?? 'حدث خطأ في النظام';
      }

      return BookingResult.failure(errorMessage);
    } catch (e, stack) {
      debugPrint('❌ [SESSION REQUEST] Unexpected error: $e');
      debugPrintStack(stackTrace: stack);

      if (lockResult?.success == true) {
        await _releaseSlotLock(lockResult!).catchError((releaseErr) {
          debugPrint(
              '⚠️ [SESSION REQUEST] Lock release also failed: $releaseErr');
        });
      }

      return BookingResult.failure(e.toString());
    }
  }

  // ── Slot Locking ───────────────────────────────────────────────────────────

  Future<SlotLockResult> _lockAvailabilitySlot({
    required String mohaffezId,
    required DateTime slotDate,
    required String timeSlot,
    required String sessionType,
  }) async {
    try {
      final availabilityQuery = await _firestore
          .collection('users')
          .doc(mohaffezId)
          .collection('availability')
          .where('dayOfWeek', isEqualTo: slotDate.weekday)
          .limit(1)
          .get();

      if (availabilityQuery.docs.isEmpty) {
        return const SlotLockResult(success: false, error: 'الموعد غير متاح');
      }

      final availabilityDocRef = availabilityQuery.docs.first.reference;
      final normalizedSelectedSlot = _normalizeTimeSlot(timeSlot);

      return _firestore.runTransaction((transaction) async {
        final availabilityDoc = await transaction.get(availabilityDocRef);
        final data = availabilityDoc.data();
        if (data == null) {
          return const SlotLockResult(success: false, error: 'الموعد غير متاح');
        }

        final timeSlots =
            List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);

        final slotIndex = timeSlots.indexWhere((slot) {
          final slotTime =
              _normalizeTimeSlot('${slot['startTime']}-${slot['endTime']}');
          return slotTime == normalizedSelectedSlot &&
              (slot['sessionType'] as String?) == sessionType;
        });

        if (slotIndex == -1) {
          return const SlotLockResult(
              success: false, error: 'الموعد غير موجود');
        }

        final slot = timeSlots[slotIndex];
        if (slot['enabled'] == false || slot['lockedBy'] != null) {
          return const SlotLockResult(
            success: false,
            error: 'هذا الموعد محجوز بالفعل. الرجاء اختيار موعد آخر.',
          );
        }

        final lockRef = _firestore.collection('slotLocks').doc();
        final expiresAt = DateTime.now().add(const Duration(hours: 2));

        timeSlots[slotIndex] = {
          ...slot,
          'lockedBy': 'request',
          'lockId': lockRef.id,
          'lockedAt': FieldValue.serverTimestamp(),
        };

        transaction.update(availabilityDoc.reference, {
          'timeSlots': timeSlots,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(lockRef, {
          'mohaffezId': mohaffezId,
          'slotDate': Timestamp.fromDate(slotDate),
          'timeSlot': timeSlot,
          'sessionType': sessionType,
          'availabilityDocId': availabilityDoc.id,
          'lockedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'released': false,
          'releasedAt': null,
        });

        return SlotLockResult(
          success: true,
          lockId: lockRef.id,
          availabilityDocId: availabilityDoc.id,
        );
      });
      // FIX-4: Log lock acquisition failures and return detailed error payload
    } catch (e, stack) {
      debugPrint('⚠️ lockAvailabilitySlot failed: $e');
      debugPrintStack(stackTrace: stack);
      return SlotLockResult(
        success: false,
        lockId: null,
        availabilityDocId: null,
        error: e.toString(),
      );
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
      final requestDoc =
          await _firestore.collection('sessionRequests').doc(requestId).get();

      if (!requestDoc.exists) {
        return BookingResult.failure('الطلب غير موجود');
      }

      final requestData = requestDoc.data()!;
      final slotLockId = requestData['slotLockId'] as String?;
      final mohaffezId = requestData['mohaffezId'] as String?;
      final studentId = requestData['studentId'] as String?;
      final studentName = requestData['studentName'] as String?;
      final slotDate = requestData['slotDate'] as Timestamp?;
      final timeSlot = requestData['preferredTimeSlot'] as String?;
      final sessionType = requestData['sessionType'] as String?;

      DocumentReference? availRef;
      if (mohaffezId != null && slotDate != null) {
        availRef = await _findAvailabilityRef(
          mohaffezId: mohaffezId,
          slotDate: slotDate,
        );
      }

      await _firestore.runTransaction((transaction) async {
        Map<String, dynamic>? availData;
        final resolvedAvailRef = availRef;
        if (resolvedAvailRef != null) {
          final availSnap = await transaction.get(resolvedAvailRef);
          availData = availSnap.data() as Map<String, dynamic>?;
        }

        transaction.update(requestDoc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'student',
        });

        if (slotLockId != null) {
          final lockRef = _firestore.collection('slotLocks').doc(slotLockId);
          transaction.delete(lockRef);
        }

        if (resolvedAvailRef != null &&
            availData != null &&
            timeSlot != null &&
            sessionType != null) {
          final updated =
              _computeRestoredSlots(availData, timeSlot, sessionType);
          if (updated != null) {
            transaction.update(resolvedAvailRef, {
              'timeSlots': updated,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        if (mohaffezId != null) {
          final notifRef = _firestore.collection('notifications').doc();
          transaction.set(notifRef, {
            'userId': mohaffezId,
            'recipientId': mohaffezId,
            'senderId': studentId,
            'title': 'تم إلغاء طلب الحجز',
            'body': 'قام $studentName بإلغاء طلب الحجز',
            'type': 'sessionCancelled',
            'isRead': false,
            'requestId': requestId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      return BookingResult.success(requestId);
    } catch (e, stack) {
      debugPrint('❌ [cancelSessionRequest] Error: $e');
      debugPrintStack(stackTrace: stack);
      return BookingResult.failure(e.toString());
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _normalizeTimeSlot(String raw) => raw.replaceAll(' ', '');

  Future<DocumentReference?> _findAvailabilityRef({
    required String mohaffezId,
    required Timestamp slotDate,
  }) async {
    final date = slotDate.toDate();
    final dayOfWeek = date.weekday;
    final snap = await _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('availability')
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first.reference;
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
        .where('status',
            whereIn: ['pending', 'awaiting_payment', 'rejected', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return <String, dynamic>{...data, 'id': doc.id};
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> getMohaffezRequests(String mohaffezId) {
    return _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', whereIn: ['pending', 'awaitingpayment'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
            .toList());
  }
}
