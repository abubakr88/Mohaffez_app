import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
    String? error,
  }) {
    return BookingState(
      selectedPaymentMethod: clearSelectedPaymentMethod
          ? null
          : selectedPaymentMethod ?? this.selectedPaymentMethod,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      sessionId: sessionId ?? this.sessionId,
      error: error ?? this.error,
    );
  }
}

class BookingFlowNotifier extends StateNotifier<BookingState> {
  BookingFlowNotifier(this._bookingService) : super(const BookingState());

  final BookingService _bookingService;

  void setSelectedPaymentMethod(BookingPaymentMethod method) {
    state = state.copyWith(selectedPaymentMethod: method);
  }

  void clearSelectedPaymentMethod() {
    state = state.copyWith(clearSelectedPaymentMethod: true);
  }

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
      );

      if (result.isSuccess) {
        state = state.copyWith(
          isSubmitting: false,
          isSuccess: true,
          sessionId: result.sessionId,
        );
      } else {
        state = state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          error: result.errorMessage,
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        isSuccess: false,
        error: e.toString(),
      );
      return BookingResult.failure(e.toString());
    }
  }

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
  }) async {
    state = state.copyWith(isSubmitting: true);
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
      );

      if (result.isSuccess) {
        clearSelectedPaymentMethod();
      }

      return result;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

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

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  }) async {
    try {
      debugPrint('🔄 [FREE SESSION] Starting Cloud Function call...');
      debugPrint('📍 Function: confirmFreeSession');
      debugPrint('👤 Student: $studentId');
      debugPrint('👨‍🏫 Mohaffez: $mohaffezId');
      debugPrint('🎟️ Promo: $promoCode');

      final callable = FirebaseFunctions.instance.httpsCallable(
        'confirmFreeSession',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      final data = {
        'mohaffezId': mohaffezId,
        'mohaffezName': mohaffezName,
        'studentId': studentId,
        'studentName': studentName,
        'sessionType': sessionType,
        'preferredTimeSlot': preferredTimeSlot,
        'slotDate': slotDate.toIso8601String(),
        'slotStart': slotStart.toIso8601String(),
        'slotEnd': slotEnd.toIso8601String(),
        'imamAddressText': imamAddressText,
        'imamAddressLat': imamAddressLat,
        'imamAddressLng': imamAddressLng,
        'mohaffezPhone': mohaffezPhone,
        'promoCode': promoCode,
      };

      debugPrint('📦 Payload: ${data.keys.join(", ")}');

      final result = await callable.call(data);

      debugPrint('✅ [FREE SESSION] Cloud Function response received');
      debugPrint('📄 Response: ${result.data}');

      if (result.data is Map && result.data['success'] == true) {
        final sessionId = result.data['sessionId'] as String?;
        if (sessionId != null) {
          debugPrint('🎉 Free session created successfully: $sessionId');
          return BookingResult.success(sessionId);
        } else {
          debugPrint('⚠️ Success but no sessionId returned');
          return BookingResult.failure('تم الحجز ولكن لم يتم إرجاع معرف الجلسة');
        }
      } else {
        final errorMsg = result.data['message'] as String? ?? 'فشل في إنشاء الجلسة';
        debugPrint('❌ Cloud Function returned failure: $errorMsg');
        return BookingResult.failure(errorMsg);
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [FREE SESSION] FirebaseFunctionsException');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Details: ${e.details}');

      String errorMessage;
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
      debugPrint('Stack trace: $stackTrace');
      return BookingResult.failure('حدث خطأ غير متوقع: ${e.toString()}');
    }
  }

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
  }) async {
    SlotLockResult? lockResult;
    try {
      final DateTime actualSlotDate =
          slotDate ?? DateTime(slotStart.year, slotStart.month, slotStart.day);

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final canLockAvailability = currentUid != null && currentUid == mohaffezId;

      if (canLockAvailability) {
        lockResult = await _lockAvailabilitySlot(
          mohaffezId: mohaffezId,
          slotDate: actualSlotDate,
          timeSlot: preferredTimeSlot,
          sessionType: sessionType,
        );
      } else {
        lockResult = const SlotLockResult(success: true);
      }

      if (!lockResult.success) {
        return BookingResult.failure(lockResult.error ?? 'فشل الحجز');
      }

      final Map<String, dynamic> requestData = {
        'mohaffezId': mohaffezId,
        'studentId': studentId,
        'studentName': studentName,
        'mohaffezName': mohaffezName,
        'sessionType': sessionType,
        'preferredTimeSlot': preferredTimeSlot,
        'slotStart': Timestamp.fromDate(slotStart),
        'slotEnd': Timestamp.fromDate(slotEnd),
        'slotDate': Timestamp.fromDate(actualSlotDate),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'imamAddressText': imamAddressText,
        'imamAddressLat': imamAddressLat,
        'imamAddressLng': imamAddressLng,
        'mohaffezPhone': mohaffezPhone,
        'isPaid': isPaid,
        'subscriptionId': subscriptionId,
        'requiresPaymentOnAcceptance': requiresPaymentOnAcceptance,
        'selectedPaymentMethod':
            (paymentMethod ?? BookingPaymentMethod.payAfterAcceptance).value,
        'slotLockId': lockResult.lockId,
        'slotLockedAt': FieldValue.serverTimestamp(),
        'paymentDeadline': null,
        'reminderSent': false,
      };

      final docRef =
          await _firestore.collection('sessionRequests').add(requestData);

      return BookingResult.success(docRef.id);
    } catch (e) {
      if (lockResult?.success == true) {
        await _releaseSlotLock(lockResult!).catchError((_) {});
      }
      return BookingResult.failure(e.toString());
    }
  }

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
        return const SlotLockResult(
          success: false,
          error: 'الموعد غير متاح',
        );
      }

      final availabilityDocRef = availabilityQuery.docs.first.reference;
      final normalizedSelectedSlot = _normalizeTimeSlot(timeSlot);

      return _firestore.runTransaction((transaction) async {
        final availabilityDoc = await transaction.get(availabilityDocRef);
        final data = availabilityDoc.data();
        if (data == null) {
          return const SlotLockResult(
            success: false,
            error: 'الموعد غير متاح',
          );
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
            success: false,
            error: 'الموعد غير موجود',
          );
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
    } catch (_) {
      return const SlotLockResult(
        success: false,
        error: 'فشل في حجز الموعد. حاول مرة أخرى.',
      );
    }
  }

  Future<void> _releaseSlotLock(SlotLockResult lockResult) async {
    if (lockResult.lockId == null) {
      return;
    }
    final lockRef = _firestore.collection('slotLocks').doc(lockResult.lockId);
    final lockDoc = await lockRef.get();
    if (!lockDoc.exists) {
      return;
    }

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

  String _normalizeTimeSlot(String raw) {
    return raw.replaceAll(' ', '');
  }

  Future<BookingResult> cancelSessionRequest(String requestId) async {
    try {
      // Get request data first
      final requestDoc = await _firestore
          .collection('sessionRequests')
          .doc(requestId)
          .get();
      
      if (!requestDoc.exists) {
        return BookingResult.failure('الطلب غير موجود');
      }
      
      final requestData = requestDoc.data()!;
      final slotLockId = requestData['slotLockId'] as String?;
      final mohaffezId = requestData['mohaffezId'] as String?;
      final studentId = requestData['studentId'] as String?;
      final studentName = requestData['studentName'] as String?;

      // Run in transaction for atomicity
      await _firestore.runTransaction((transaction) async {
        // 1. Update request status
        transaction.update(requestDoc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'student',
        });

        // 2. Delete slot lock if exists
        if (slotLockId != null) {
          final lockRef = _firestore.collection('slotLocks').doc(slotLockId);
          transaction.delete(lockRef);
        }
      });

      // 3. Restore availability slot (outside transaction due to query)
      if (mohaffezId != null) {
        await _restoreAvailabilitySlot(
          mohaffezId: mohaffezId,
          slotDate: requestData['slotDate'] as Timestamp,
          timeSlot: requestData['preferredTimeSlot'] as String,
          sessionType: requestData['sessionType'] as String,
        );
      }

      // 4. Send notification to mohaffez
      if (mohaffezId != null) {
        await _firestore.collection('notifications').add({
          'userId': mohaffezId,
          'recipientId': mohaffezId,
          'senderId': studentId,
          'title': 'تم إلغاء طلب الحجز',
          'body': 'قام $studentName بإلغاء طلب الحجز',
          'type': 'session_cancelled',
          'isRead': false,
          'requestId': requestId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return BookingResult.success(requestId);
    } catch (e, stack) {
      debugPrint('❌ Error cancelling request: $e');
      debugPrint('Stack: $stack');
      return BookingResult.failure('فشل إلغاء الطلب: ${e.toString()}');
    }
  }

  Future<void> _restoreAvailabilitySlot({
    required String mohaffezId,
    required Timestamp slotDate,
    required String timeSlot,
    required String sessionType,
  }) async {
    try {
      final date = slotDate.toDate();
      final dayOfWeek = date.weekday;

      final availabilitySnapshot = await _firestore
          .collection('users')
          .doc(mohaffezId)
          .collection('availability')
          .where('dayOfWeek', isEqualTo: dayOfWeek)
          .limit(1)
          .get();

      if (availabilitySnapshot.docs.isEmpty) return;

      final availabilityDoc = availabilitySnapshot.docs.first;
      final data = availabilityDoc.data();
      final timeSlots = List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);

      final normalizedSelected = _normalizeTimeSlot(timeSlot);
      var restored = false;

      for (var slot in timeSlots) {
        final slotTime = _normalizeTimeSlot('${slot['startTime']}-${slot['endTime']}');
        if (slotTime == normalizedSelected && slot['sessionType'] == sessionType) {
          slot['enabled'] = true;
          slot.remove('lockedBy');
          slot.remove('lockId');
          slot.remove('lockedAt');
          restored = true;
          break;
        }
      }

      if (restored) {
        await availabilityDoc.reference.update({
          'timeSlots': timeSlots,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error restoring availability: $e');
      // Don't fail the cancellation if this fails
    }
  }

  Stream<List<Map<String, dynamic>>> getStudentRequests(String studentId) {
    return _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Stream<List<Map<String, dynamic>>> getMohaffezRequests(String mohaffezId) {
    return _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', whereIn: ['pending', 'awaiting_payment'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }
}
