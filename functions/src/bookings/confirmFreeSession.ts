// functions/src/bookings/confirmFreeSession.ts

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db, FieldValue } from "../utils/admin";
import { EventStore } from "../services/EventStore";
import { sanitizeForFirestore } from "../utils/firestoreSanitizer";
import {
  buildBundleEntitlementValues,
  isBundlePlan,
  promoBundleSubscriptionId,
} from "../payments/paymobBundleEntitlement";
import { PaymentEventType } from "../types/events.types";

const STATUS = {
  PENDING: 'pending',
  AWAITING_PAYMENT: 'awaitingpayment',
  AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
  ACCEPTED: 'accepted',
  REJECTED: 'rejected',
  CANCELLED: 'cancelled',
} as const;

// FIX-2: Parse Flutter ISO strings without timezone as UTC to prevent server-local shift
function parseFlutterDate(iso: string): Date {
  // If the string has no timezone info, treat it as UTC
  if (!iso.endsWith('Z') && !/[+\-]\d{2}:\d{2}$/.test(iso)) {
    return new Date(iso + 'Z');
  }
  return new Date(iso);
}

function optionalString(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : null;
}

function optionalNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function mapValue(value: unknown): Record<string, unknown> {
  return value != null && typeof value === 'object'
    ? value as Record<string, unknown>
    : {};
}

function optionalTimestamp(
  value: unknown
): FirebaseFirestore.Timestamp | null {
  if (value instanceof admin.firestore.Timestamp) return value;
  if (value instanceof Date) return admin.firestore.Timestamp.fromDate(value);
  if (typeof value === 'string') {
    const parsed = parseFlutterDate(value);
    if (!Number.isNaN(parsed.getTime())) {
      return admin.firestore.Timestamp.fromDate(parsed);
    }
  }
  return null;
}

// FIXED: BUG-5 - strip both hyphens AND en-dashes
function normalizeTimeSlot(raw: string): string {
  return raw.replace(/\s/g, '').replace(/[\u2013\u2014]/g, '-');
}

export const confirmFreeSession = functions.https.onCall(async (data, context) => {
  functions.logger.info("🎫 confirmFreeSession v6.0 (17/2/2026) - Enhanced Logging");

  // 1. Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "المستخدم غير مصادق عليه");
  }
  const studentId = context.auth.uid;

  // 2. Validate input
  const {
    mohaffezId,
    mohaffezName,
    studentName,
    sessionType,
    preferredProvider,
    preferredTimeSlot,
    slotDate,
    slotStart,
    slotEnd,
    imamAddressText,
    imamAddressLat,
    imamAddressLng,
    mohaffezPhone,
    studentPhone,
    promoCode,
    requestId,
    paymentId,
    guardianId,
    guardianName,
    studentProfileId,
    studentProfileName,
    studentProfileGender,
    studentProfileBirthDate,
    studentAge,
  } = data;
  const normalizedPromoCode =
    typeof promoCode === "string" ? promoCode.trim().toUpperCase() : "";
  const normalizedPaymentId = optionalString(paymentId);

  // ✅ LOG INPUT PARAMETERS
  functions.logger.info("📥 Input parameters received", {
    hasRequestId: !!requestId,
    requestId: requestId || "NOT_PROVIDED",
    hasPaymentId: normalizedPaymentId != null,
    paymentId: normalizedPaymentId,
    studentId,
    mohaffezId,
    promoCode,
  });

  if (
    !mohaffezId ||
    !mohaffezName ||
    !studentName ||
    !sessionType ||
    !preferredTimeSlot ||
    !slotDate ||
    !slotStart ||
    !slotEnd ||
    !normalizedPromoCode
  ) {
    throw new functions.https.HttpsError("invalid-argument", "بيانات غير مكتملة");
  }

  // 3. ✅ QUICK PRE-CHECK (non-blocking, advisory only)
  if (requestId) {
    const quickCheck = await db
      .collection("hafizSessions")
      .where("requestId", "==", requestId)
      .limit(1)
      .get();

    if (!quickCheck.empty) {
      const session = quickCheck.docs[0];
      functions.logger.warn("⚠️ Session already exists (quick pre-check)", {
        requestId,
        sessionId: session.id,
      });
      return {
        success: true,
        sessionId: session.id,
        requestId: requestId,
        message: "الجلسة موجودة بالفعل",
      };
    }
  }

  // 5. ✅ CRITICAL FIX: Move ALL logic inside transaction
  const result = await db.runTransaction(async (transaction) => {
    // FIX-1: Move promo code read/validation into transaction to avoid TOCTOU race
    const promoQuery = db
      .collection("promoCodes")
      .where("code", "==", normalizedPromoCode)
      .limit(1);
    const promoSnapshot = await transaction.get(promoQuery);

    if (promoSnapshot.empty) {
      throw new functions.https.HttpsError("not-found", "كود الخصم غير موجود");
    }

    const promoDoc = promoSnapshot.docs[0];
    const promoData = promoDoc.data();
    const redemptionRef = promoDoc.ref
      .collection("redemptions")
      .doc(studentId);
    const redemptionSnapshot = await transaction.get(redemptionRef);
    const redemptionData = redemptionSnapshot.data();
    const currentUserUseCount =
      typeof redemptionData?.useCount === "number"
        ? redemptionData.useCount
        : 0;
    const perUserLimit = 1;

    if (!promoData.isActive) {
      throw new functions.https.HttpsError("failed-precondition", "كود الخصم غير نشط");
    }

    const discountType = promoData.type ?? promoData.discountType;
    const discountValue =
      promoData.discountPercent ??
      promoData.discountValue ??
      promoData.discount;
    const isPercentageDiscount =
      discountType === "percentage" || discountType === "percent";

    if (!isPercentageDiscount || Number(discountValue) !== 100) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "كود الخصم يجب أن يكون 100%"
      );
    }

    if (promoData.expiryDate && promoData.expiryDate.toDate() < new Date()) {
      throw new functions.https.HttpsError("failed-precondition", "كود الخصم منتهي الصلاحية");
    }

    if (promoData.usageLimit && promoData.usedCount >= promoData.usageLimit) {
      throw new functions.https.HttpsError("failed-precondition", "تم استخدام كود الخصم بالكامل");
    }

    functions.logger.info("✅ Promo code validated", {
      promoCode: normalizedPromoCode,
      discountPercent: Number(discountValue),
      usedCount: promoData.usedCount,
      usageLimit: promoData.usageLimit,
      perUserLimit,
      currentUserUseCount,
    });
    functions.logger.info("🔄 Transaction started");

    const slotDateTimestamp = admin.firestore.Timestamp.fromDate(parseFlutterDate(slotDate));
    const slotStartTimestamp = admin.firestore.Timestamp.fromDate(parseFlutterDate(slotStart));
    const slotEndTimestamp = admin.firestore.Timestamp.fromDate(parseFlutterDate(slotEnd));

    // ============================================
    // ✅ STEP 1: IDEMPOTENCY CHECK INSIDE TRANSACTION
    // ============================================
    
    // Check 1: By requestId
    if (requestId) {
      const existingByRequestQuery = db
        .collection("hafizSessions")
        .where("requestId", "==", requestId)
        .limit(1);
      
      const existingByRequest = await transaction.get(existingByRequestQuery);
      
      if (!existingByRequest.empty) {
        const session = existingByRequest.docs[0];
        functions.logger.warn("⚠️ Session already exists (requestId check inside transaction)", {
          requestId,
          sessionId: session.id,
        });
        return {
          __idempotent: true,
          success: true,
          sessionId: session.id,
          requestId: requestId,
          message: "الجلسة موجودة بالفعل",
        };
      }
    }

    // Check 2: By paymentId
    if (normalizedPaymentId) {
      const existingByPaymentQuery = db
        .collection("hafizSessions")
        .where("paymentId", "==", normalizedPaymentId)
        .limit(1);
      
      const existingByPayment = await transaction.get(existingByPaymentQuery);
      
      if (!existingByPayment.empty) {
        const session = existingByPayment.docs[0];
        const sessionData = session.data();
        functions.logger.warn("⚠️ Session already exists (paymentId check)", {
          paymentId: normalizedPaymentId,
          sessionId: session.id,
        });
        return {
          __idempotent: true,
          success: true,
          sessionId: session.id,
          requestId: sessionData.requestId || null,
          message: "الجلسة موجودة بالفعل",
        };
      }
    }

    // Enforce the per-user limit only after idempotency checks. A retried
    // successful request must return its existing session, not a false
    // "already used" error.
    if (
      currentUserUseCount >= perUserLimit ||
      (!redemptionSnapshot.exists && promoData.lastUsedBy === studentId)
    ) {
      throw new functions.https.HttpsError(
        "already-exists",
        "لقد استخدمت كود الخصم من قبل، ولا يمكن استخدامه أكثر من مرة."
      );
    }

    // The original booking request is the source of truth for the reserved
    // slot. createSessionRequest disables that availability slot as soon as
    // the request is created, so a disabled slot is expected here when it
    // belongs to this exact request.
    if (!requestId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'معرف الطلب مطلوب للجلسات المجانية'
      );
    }

    const requestRef = db.collection('sessionRequests').doc(requestId);
    const existingRequest = await transaction.get(requestRef);

    functions.logger.info("🔍 Checking existing request document", {
      requestId,
      exists: existingRequest.exists,
      status: existingRequest.exists ? existingRequest.data()?.status : "N/A",
    });

    if (!existingRequest.exists) {
      throw new functions.https.HttpsError('not-found', 'طلب الجلسة غير موجود');
    }

    const existingRequestData = existingRequest.data()!;

    if (
      existingRequestData.studentId !== studentId ||
      existingRequestData.mohaffezId !== mohaffezId
    ) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'طلب الجلسة لا يخص هذا المستخدم أو المحفظ'
      );
    }

    if (
      existingRequestData.status === STATUS.REJECTED ||
      existingRequestData.status === STATUS.CANCELLED
    ) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'لا يمكن تأكيد طلب مرفوض أو ملغي'
      );
    }

    if (
      existingRequestData.status === STATUS.ACCEPTED &&
      existingRequestData.sessionId
    ) {
      return {
        __idempotent: true,
        success: true,
        sessionId: existingRequestData.sessionId,
        requestId,
        message: 'الجلسة مؤكدة بالفعل',
      };
    }

    let paymentRef: FirebaseFirestore.DocumentReference | null = null;
    let paymentData: Record<string, unknown> | null = null;
    let paymentMetadata: Record<string, unknown> = {};
    let bundleSubscriptionId: string | null = null;
    let bundleSubscriptionRef: FirebaseFirestore.DocumentReference | null = null;

    if (normalizedPaymentId) {
      paymentRef = db.collection('payments').doc(normalizedPaymentId);
      const paymentSnapshot = await transaction.get(paymentRef);
      if (!paymentSnapshot.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'سجل الدفع المجاني غير موجود'
        );
      }

      paymentData = paymentSnapshot.data() as Record<string, unknown>;
      paymentMetadata = mapValue(paymentData.metadata);
      const paymentPromoCode = optionalString(paymentMetadata.promoCode)?.toUpperCase();
      const paymentRequestId = optionalString(
        paymentData.requestId ?? paymentMetadata.requestId
      );
      const paymentAmount = optionalNumber(paymentData.amount) ?? 0;

      if (
        paymentData.studentId !== studentId ||
        paymentData.mohaffezId !== mohaffezId ||
        (paymentRequestId != null && paymentRequestId !== requestId) ||
        paymentAmount > 0.01 ||
        paymentPromoCode !== normalizedPromoCode
      ) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'سجل الدفع لا يطابق طلب الحجز المجاني'
        );
      }

      if (isBundlePlan(paymentMetadata, paymentData)) {
        bundleSubscriptionId = promoBundleSubscriptionId(normalizedPaymentId);
        bundleSubscriptionRef = db
          .collection('subscriptions')
          .doc(bundleSubscriptionId);
        const bundleSubscriptionSnapshot = await transaction.get(
          bundleSubscriptionRef
        );
        if (bundleSubscriptionSnapshot.exists) {
          throw new functions.https.HttpsError(
            'already-exists',
            'اشتراك الباقة المجانية موجود بالفعل'
          );
        }
      }
    }

    const requestSlotDate = optionalTimestamp(existingRequestData.slotDate);
    const requestMatchesSlot =
      normalizeTimeSlot(existingRequestData.preferredTimeSlot ?? '') ===
        normalizeTimeSlot(preferredTimeSlot) &&
      existingRequestData.sessionType === sessionType &&
      requestSlotDate?.toMillis() === slotDateTimestamp.toMillis();

    if (!requestMatchesSlot) {
      functions.logger.error('confirmFreeSession: request slot mismatch', {
        requestId,
        requestTimeSlot: existingRequestData.preferredTimeSlot,
        payloadTimeSlot: preferredTimeSlot,
        requestSessionType: existingRequestData.sessionType,
        payloadSessionType: sessionType,
        requestSlotDate: requestSlotDate?.toDate().toISOString() ?? null,
        payloadSlotDate: slotDateTimestamp.toDate().toISOString(),
      });
      throw new functions.https.HttpsError(
        'failed-precondition',
        'بيانات الموعد لا تطابق طلب الحجز'
      );
    }

    // ============================================
    // ✅ STEP 2: CHECK FOR EXISTING SESSION ON THIS SLOT
    // ============================================
    const existingSessionOnSlotQuery = db
      .collection("hafizSessions")
      .where("mohaffezId", "==", mohaffezId)
      .where("sessionDate", "==", slotDateTimestamp)
      .where("preferredTimeSlot", "==", preferredTimeSlot)
      .where("status", "in", [STATUS.ACCEPTED, STATUS.PENDING]);
    
    const existingSessionsOnSlot = await transaction.get(existingSessionOnSlotQuery);
    
    if (!existingSessionsOnSlot.empty) {
      functions.logger.error("❌ Slot already booked", {
        mohaffezId,
        slotDate,
        preferredTimeSlot,
        existingSessionId: existingSessionsOnSlot.docs[0].id,
      });
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "هذا التوقيت محجوز بالفعل"
      );
    }

    // ============================================
    // ✅ STEP 3: READ AVAILABILITY AND VERIFY SLOT IS ENABLED
    // ============================================
    const slotDateObj = parseFlutterDate(slotDate);
    const dayOfWeek = slotDateObj.getDay() === 0 ? 7 : slotDateObj.getDay();

    const availabilityQuery = db
      .collection("users")
      .doc(mohaffezId)
      .collection("availability")
      .where("dayOfWeek", "==", dayOfWeek)
      .limit(1);

    const availabilitySnapshot = await transaction.get(availabilityQuery);
    const availabilityDoc = !availabilitySnapshot.empty 
      ? availabilitySnapshot.docs[0] 
      : null;

    // Verify slot is actually available
    if (availabilityDoc) {
      const availabilityData = availabilityDoc.data();
      if (availabilityData && Array.isArray(availabilityData.timeSlots)) {
        const timeSlots = availabilityData.timeSlots;
        const normalizedSlot = normalizeTimeSlot(preferredTimeSlot);
        
        let slotFound = false;
        let slotEnabled = false;
        
        for (const slot of timeSlots) {
          const slotTime = normalizeTimeSlot(`${slot.startTime}-${slot.endTime}`);
          if (slotTime === normalizedSlot && slot.sessionType === sessionType) {
            slotFound = true;
            slotEnabled = slot.enabled === true;
            break;
          }
        }
        
        if (slotFound && !slotEnabled) {
          functions.logger.info("✅ Slot is reserved by the current request", {
            mohaffezId,
            requestId,
            dayOfWeek,
            timeSlot: normalizedSlot,
          });
        }
      }
    }

    // ============================================
    // ✅ STEP 4: HANDLE REQUEST DOCUMENT
    // ============================================
    const isUpdatingExisting = true;

    functions.logger.info("✅ Will UPDATE existing request", {
      requestId,
      currentStatus: existingRequestData.status,
      isUpdatingExisting,
    });

    const sessionRef = db.collection("hafizSessions").doc();
    const learnerSnapshot = {
      guardianId:
        optionalString(guardianId) ??
        optionalString(existingRequestData?.['guardianId']) ??
        studentId,
      guardianName:
        optionalString(guardianName) ??
        optionalString(existingRequestData?.['guardianName']),
      studentProfileId:
        optionalString(studentProfileId) ??
        optionalString(existingRequestData?.['studentProfileId']),
      studentProfileName:
        optionalString(studentProfileName) ??
        optionalString(existingRequestData?.['studentProfileName']) ??
        optionalString(studentName),
      studentProfileGender:
        optionalString(studentProfileGender) ??
        optionalString(existingRequestData?.['studentProfileGender']),
      studentProfileBirthDate:
        optionalTimestamp(studentProfileBirthDate) ??
        optionalTimestamp(existingRequestData?.['studentProfileBirthDate']),
      studentAge:
        optionalNumber(studentAge) ??
        optionalNumber(existingRequestData?.['studentAge']),
    };
    const effectivePreferredProvider =
      sessionType === 'online'
        ? optionalString(preferredProvider) ??
          optionalString(existingRequestData.preferredProvider)
        : null;

    const sessionDetails = mapValue(paymentMetadata.sessionDetails);
    const planId = optionalString(paymentMetadata.planId) ??
      optionalString(existingRequestData.planId);
    const planTitle = optionalString(paymentMetadata.planTitle) ??
      optionalString(existingRequestData.planTitle);
    const sessionsCount = optionalNumber(paymentMetadata.sessionsCount) ??
      optionalNumber(existingRequestData.sessionsCount);
    const validityDays = optionalNumber(paymentMetadata.validityDays) ??
      optionalNumber(existingRequestData.validityDays);
    const sessionDurationMinutes =
      optionalNumber(existingRequestData.sessionDurationMinutes) ??
      optionalNumber(sessionDetails.sessionDurationMinutes) ??
      optionalNumber(paymentMetadata.sessionDurationMinutes);
    const isBundlePayment =
      paymentData != null && isBundlePlan(paymentMetadata, paymentData);
    const sessionWriteData: Record<string, unknown> = {
      requestId: requestRef.id,
      mohaffezId,
      studentId,
      mohaffezName,
      studentName,
      ...learnerSnapshot,
      sessionType,
      preferredProvider: effectivePreferredProvider,
      location: imamAddressText || "",
      mohaffezPhone: mohaffezPhone || null,
      studentPhone:
        typeof studentPhone === 'string' && studentPhone.trim().length > 0
          ? studentPhone.trim()
          : null,
      imamAddressLat: imamAddressLat || null,
      imamAddressLng: imamAddressLng || null,
      imamAddressText: imamAddressText || null,
      preferredTimeSlot,
      timeSlot: preferredTimeSlot,
      sessionDate: slotDateTimestamp,
      slotStart: slotStartTimestamp,
      slotEnd: slotEndTimestamp,
      status: STATUS.ACCEPTED,
      isPaid: true,
      sessionPrice: 0.0,
      promoCode: normalizedPromoCode,
      paymentId: normalizedPaymentId,
      ...(planId ? { planId } : {}),
      ...(planTitle ? { planTitle } : {}),
      ...(isBundlePayment ? { planType: 'bundle' } : {}),
      ...(sessionsCount != null ? { sessionsCount } : {}),
      ...(validityDays != null ? { validityDays } : {}),
      ...(sessionDurationMinutes != null
        ? { sessionDurationMinutes: Math.trunc(sessionDurationMinutes) }
        : {}),
      ...(bundleSubscriptionId ? { subscriptionId: bundleSubscriptionId } : {}),
      createdAt: FieldValue.serverTimestamp(),
      acceptedAt: FieldValue.serverTimestamp(),
      reminder24hSent: false,
      reminder1hSent: false,
      juzCount: 1,
      sessionRating: 10,
    };

    let bundleSubscriptionWriteData: Record<string, unknown> | null = null;
    let bundleRemainingSessions: number | null = null;
    if (
      isBundlePayment &&
      normalizedPaymentId &&
      paymentData &&
      bundleSubscriptionId &&
      bundleSubscriptionRef
    ) {
      const entitlement = buildBundleEntitlementValues({
        paymentId: normalizedPaymentId,
        payment: paymentData,
        metadata: paymentMetadata,
        requestId: requestRef.id,
        request: existingRequestData,
        sessionId: sessionRef.id,
        session: sessionWriteData,
        transactionId: normalizedPaymentId,
        subscriptionId: bundleSubscriptionId,
        paymentType: 'promo',
        paymentGateway: 'promo',
        promoCode: normalizedPromoCode,
      });
      const startDate = admin.firestore.Timestamp.now();
      const expiryDate = entitlement.validityDays == null
        ? null
        : admin.firestore.Timestamp.fromMillis(
            startDate.toMillis() + entitlement.validityDays * 86400000
          );
      bundleRemainingSessions = entitlement.remainingSessions;
      bundleSubscriptionWriteData = sanitizeForFirestore({
        ...entitlement.data,
        promoCode: normalizedPromoCode,
        promoDiscount: 100,
        startDate,
        expiryDate,
        lastUsedAt: startDate,
        createdAt: startDate,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // ============================================
    // ✅ STEP 5: WRITE PHASE
    // ============================================
    const requestUpdateData = {
      status: STATUS.ACCEPTED,
      isPaid: true,
      paymentAmount: 0.0,
      promoCode: normalizedPromoCode,
      promoDiscount: 100,
      notificationsAlreadySent: true,
      sessionId: sessionRef.id,
      ...(bundleSubscriptionId
        ? {
            subscriptionId: bundleSubscriptionId,
            planType: 'bundle',
          }
        : {}),
      ...learnerSnapshot,
      acceptedAt: FieldValue.serverTimestamp(),
      paidAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (isUpdatingExisting) {
      // ✅ UPDATE existing request
      transaction.update(requestRef, requestUpdateData);
      functions.logger.info("📝 Updating existing sessionRequest", {
        requestId: requestRef.id,
        operation: "UPDATE",
      });
    } else {
      // ✅ CREATE new request
      transaction.set(requestRef, {
        ...requestUpdateData,
        studentId,
        mohaffezId,
        studentName,
        ...learnerSnapshot,
        mohaffezName,
        sessionType,
        preferredProvider:
          sessionType === 'online' && typeof preferredProvider === 'string' && preferredProvider.length > 0
            ? preferredProvider
            : null,
        preferredTimeSlot,
        slotDate: slotDateTimestamp,
        slotStart: slotStartTimestamp,
        slotEnd: slotEndTimestamp,
        imamAddressText: imamAddressText || null,
        imamAddressLat: imamAddressLat || null,
        imamAddressLng: imamAddressLng || null,
        mohaffezPhone: mohaffezPhone || null,
        studentPhone:
          typeof studentPhone === 'string' && studentPhone.trim().length > 0
            ? studentPhone.trim()
            : null,
        requiresPaymentOnAcceptance: false,
        selectedPaymentMethod: "freesession",
        createdAt: FieldValue.serverTimestamp(),
      });
      functions.logger.info("📝 Creating NEW sessionRequest", {
        requestId: requestRef.id,
        operation: "CREATE",
      });
    }

    // Create hafizSession
    transaction.set(sessionRef, sessionWriteData);

    if (bundleSubscriptionRef && bundleSubscriptionWriteData) {
      transaction.set(bundleSubscriptionRef, bundleSubscriptionWriteData);
      const subscriptionEventRef = db.collection('paymentEvents').doc();
      transaction.set(subscriptionEventRef, sanitizeForFirestore({
        eventId: subscriptionEventRef.id,
        eventType: PaymentEventType.SUBSCRIPTION_CREATED,
        paymentId: normalizedPaymentId,
        userId: studentId,
        data: {
          requestId: requestRef.id,
          sessionId: sessionRef.id,
          subscriptionId: bundleSubscriptionId,
          totalSessions: sessionsCount,
          remainingSessions: bundleRemainingSessions,
          promoCode: normalizedPromoCode,
        },
        metadata: { source: 'client' },
        timestamp: FieldValue.serverTimestamp(),
      }));
    }

    functions.logger.info("📝 Creating hafizSession", {
      sessionId: sessionRef.id,
      requestId: requestRef.id,
    });

    // Update payment (if provided)
    if (paymentRef) {
      transaction.update(paymentRef, {
        status: "completed",
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        sessionId: sessionRef.id,
        notes: "Free session via promo code",
        ...(bundleSubscriptionId
          ? {
              subscriptionId: bundleSubscriptionId,
              planType: 'bundle',
              bundleEntitlementCreatedAt: FieldValue.serverTimestamp(),
            }
          : {}),
      });
    }

    // Increment promo code usage
    transaction.update(promoDoc.ref, {
      usedCount: FieldValue.increment(1),
      lastUsedAt: FieldValue.serverTimestamp(),
      lastUsedBy: studentId,
    });

    transaction.set(
      redemptionRef,
      {
        userId: studentId,
        promoCodeId: promoDoc.id,
        code: normalizedPromoCode,
        useCount: currentUserUseCount + 1,
        firstUsedAt:
          redemptionData?.firstUsedAt ?? FieldValue.serverTimestamp(),
        lastUsedAt: FieldValue.serverTimestamp(),
        requestId: requestRef.id,
        sessionId: sessionRef.id,
      },
      { merge: true }
    );

    // Disable availability slot
    if (availabilityDoc) {
      const availabilityData = availabilityDoc.data();
      if (availabilityData && Array.isArray(availabilityData.timeSlots)) {
        const timeSlots = availabilityData.timeSlots;
        const normalizedSlot = normalizeTimeSlot(preferredTimeSlot);

        const updatedSlots = timeSlots.map((slot: any) => {
          const slotTime = normalizeTimeSlot(`${slot.startTime}-${slot.endTime}`);
          if (slotTime === normalizedSlot && slot.sessionType === sessionType && slot.enabled) {
            return { ...slot, enabled: false };
          }
          return slot;
        });

        transaction.update(availabilityDoc.ref, {
          timeSlots: updatedSlots,
          updatedAt: FieldValue.serverTimestamp(),
        });

        functions.logger.info("🔒 Availability slot disabled", {
          mohaffezId,
          dayOfWeek,
          timeSlot: normalizedSlot,
          sessionType,
        });
      }
    } else {
      functions.logger.warn("⚠️ No availability document found", {
        mohaffezId,
        dayOfWeek,
        slotDate,
      });
    }

    // Send notifications
    const notificationRef = db.collection("notifications").doc();
    transaction.set(notificationRef, {
      userId: studentId,
      recipientId: studentId,
      senderId: mohaffezId,
      title: "تم تأكيد الجلسة المجانية! 🎉",
      body: `تم تأكيد حجز جلستك مع ${mohaffezName}`,
      type: "session_confirmed",
      isRead: false,
      data: {
        sessionId: sessionRef.id,
        requestId: requestRef.id,
        mohaffezId: mohaffezId,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    const mohaffezNotificationRef = db.collection("notifications").doc();
    transaction.set(mohaffezNotificationRef, {
      userId: mohaffezId,
      recipientId: mohaffezId,
      senderId: studentId,
      title: "جلسة مجانية جديدة! 🎁",
      body: `تم حجز جلسة مجانية مع الطالب ${studentName}`,
      type: "session_confirmed",
      isRead: false,
      data: {
        sessionId: sessionRef.id,
        requestId: requestRef.id,
        studentId: studentId,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    // ✅ FINAL SUCCESS LOG
    functions.logger.info("✅ FREE SESSION COMPLETED SUCCESSFULLY", {
      sessionId: sessionRef.id,
      requestId: requestRef.id,
      paymentId: normalizedPaymentId,
      studentId,
      mohaffezId,
      promoCode: normalizedPromoCode,
      isUpdatingExisting,
      operation: isUpdatingExisting ? "UPDATE" : "CREATE",
      transactionComplete: true,
    });

    return {
      success: true,
      sessionId: sessionRef.id,
      requestId: requestRef.id,
      paymentId: normalizedPaymentId,
      subscriptionId: bundleSubscriptionId,
      message: "تم إنشاء الجلسة المجانية بنجاح",
      isUpdatingExisting,  // ✅ Include in response
    };
  });

  // FIX-CONFIRM-2: Handle idempotent early-returns cleanly without JSON.parse.
  if ((result as any).__idempotent === true) {
    functions.logger.info('confirmFreeSession: returning existing session', result);
    return {
      success: result.success,
      sessionId: result.sessionId,
      requestId: result.requestId,
      paymentId: result.paymentId ?? null,
      message: result.message,
    };
  }

  // BUG #1 FIX: Call EventStore and update payment document after transaction commits
  // This ensures the payment event is properly recorded for analytics
  if (normalizedPaymentId) {
    try {
      const eventStore = new EventStore();
      await eventStore.appendFreeSessionCompletedEvent({
        paymentId: normalizedPaymentId,
        userId: studentId,
        promoCode: normalizedPromoCode,
      });
      functions.logger.info('EventStore: Free session completed event appended', {
        paymentId: normalizedPaymentId,
        studentId,
      });

      // Also ensure payment document is marked as completed (idempotent update)
      await db.collection('payments').doc(normalizedPaymentId).update({
        status: 'completed',
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      functions.logger.info('Payment document marked as completed', {
        paymentId: normalizedPaymentId,
      });
    } catch (eventStoreError) {
      // Do NOT throw - the session is already confirmed
      functions.logger.error('Failed to update payment status via EventStore (non-critical)', {
        paymentId: normalizedPaymentId,
        error: eventStoreError instanceof Error ? eventStoreError.message : String(eventStoreError),
      });
    }
  }

  return result;
});


