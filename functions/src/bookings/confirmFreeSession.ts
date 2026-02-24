// functions/src/bookings/confirmFreeSession.ts

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db, FieldValue } from "../utils/admin";

const STATUS = {
  PENDING: 'pending',
  AWAITING_PAYMENT: 'awaitingpayment',
  AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
  ACCEPTED: 'accepted',
  REJECTED: 'rejected',
  CANCELLED: 'cancelled',
} as const;

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
    preferredTimeSlot,
    slotDate,
    slotStart,
    slotEnd,
    imamAddressText,
    imamAddressLat,
    imamAddressLng,
    mohaffezPhone,
    promoCode,
    requestId,
    paymentId,
  } = data;

  // ✅ LOG INPUT PARAMETERS
  functions.logger.info("📥 Input parameters received", {
    hasRequestId: !!requestId,
    requestId: requestId || "NOT_PROVIDED",
    hasPaymentId: !!paymentId,
    paymentId: paymentId || null,
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
    !promoCode
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

  // 4. Verify promo code
  const promoSnapshot = await db
    .collection("promoCodes")
    .where("code", "==", promoCode)
    .limit(1)
    .get();

  if (promoSnapshot.empty) {
    throw new functions.https.HttpsError("not-found", "كود الخصم غير موجود");
  }

  const promoDoc = promoSnapshot.docs[0];
  const promoData = promoDoc.data();

  // Validate promo code
  if (!promoData.isActive) {
    throw new functions.https.HttpsError("failed-precondition", "كود الخصم غير نشط");
  }

  if (promoData.discountPercent !== 100) {
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
    promoCode,
    discountPercent: promoData.discountPercent,
    usedCount: promoData.usedCount,
    usageLimit: promoData.usageLimit,
  });

  // 5. ✅ CRITICAL FIX: Move ALL logic inside transaction
  return db.runTransaction(async (transaction) => {
    functions.logger.info("🔄 Transaction started");

    const slotDateTimestamp = admin.firestore.Timestamp.fromDate(new Date(slotDate));
    const slotStartTimestamp = admin.firestore.Timestamp.fromDate(new Date(slotStart));
    const slotEndTimestamp = admin.firestore.Timestamp.fromDate(new Date(slotEnd));

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
        throw new functions.https.HttpsError("already-exists", JSON.stringify({
          success: true,
          sessionId: session.id,
          requestId: requestId,
          message: "الجلسة موجودة بالفعل",
        }));
      }
    }

    // Check 2: By paymentId
    if (paymentId) {
      const existingByPaymentQuery = db
        .collection("hafizSessions")
        .where("paymentId", "==", paymentId)
        .limit(1);
      
      const existingByPayment = await transaction.get(existingByPaymentQuery);
      
      if (!existingByPayment.empty) {
        const session = existingByPayment.docs[0];
        const sessionData = session.data();
        functions.logger.warn("⚠️ Session already exists (paymentId check)", {
          paymentId,
          sessionId: session.id,
        });
        throw new functions.https.HttpsError("already-exists", JSON.stringify({
          success: true,
          sessionId: session.id,
          requestId: sessionData.requestId || null,
          message: "الجلسة موجودة بالفعل",
        }));
      }
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
    const slotDateObj = new Date(slotDate);
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
        const normalizedSlot = preferredTimeSlot.replace(/ /g, "");
        
        let slotFound = false;
        let slotEnabled = false;
        
        for (const slot of timeSlots) {
          const slotTime = `${slot.startTime}-${slot.endTime}`.replace(/ /g, "");
          if (slotTime === normalizedSlot && slot.sessionType === sessionType) {
            slotFound = true;
            slotEnabled = slot.enabled === true;
            break;
          }
        }
        
        if (slotFound && !slotEnabled) {
          functions.logger.error("❌ Slot is disabled", {
            mohaffezId,
            dayOfWeek,
            timeSlot: normalizedSlot,
          });
          throw new functions.https.HttpsError(
            "failed-precondition",
            "هذا التوقيت غير متاح حالياً"
          );
        }
      }
    }

    // ============================================
    // ✅ STEP 4: HANDLE REQUEST DOCUMENT
    // ============================================
    let requestRef: FirebaseFirestore.DocumentReference;
    let isUpdatingExisting = false;

    if (requestId) {
      requestRef = db.collection('sessionRequests').doc(requestId);
      const existingRequest = await transaction.get(requestRef);
      
      // ✅ LOG: Check if request exists
      functions.logger.info("🔍 Checking existing request document", {
        requestId,
        exists: existingRequest.exists,
        status: existingRequest.exists ? existingRequest.data()?.status : "N/A",
      });
      
      if (!existingRequest.exists) {
        functions.logger.error("❌ Request document not found!", {
          requestId,
          studentId,
          mohaffezId,
        });
        throw new functions.https.HttpsError('not-found', 'طلب الجلسة غير موجود');
      }
      
      const requestData = existingRequest.data();
      
      // ✅ CHECK: If already accepted
      if (requestData && requestData.status === STATUS.ACCEPTED) {
        const sessionId = requestData.sessionId;
        if (sessionId) {
          functions.logger.warn("⚠️ Request already accepted!", {
            requestId,
            sessionId,
            oldStatus: requestData.status,
          });
          throw new functions.https.HttpsError('already-exists', JSON.stringify({
            success: true,
            sessionId: sessionId,
            requestId: requestId,
            message: 'الجلسة مؤكدة بالفعل'
          }));
        }
      }
      
      isUpdatingExisting = true;
      
      // ✅ LOG: Will update existing request
      functions.logger.info("✅ Will UPDATE existing request", {
        requestId,
        currentStatus: requestData?.status,
        isUpdatingExisting: true,
      });
      
    } else {
      // ✅ LOG: No requestId provided
      functions.logger.error("❌ No requestId provided!", {
        studentId,
        mohaffezId,
        promoCode,
      });
      
      throw new functions.https.HttpsError(
        'invalid-argument', 
        'معرف الطلب مطلوب للجلسات المجانية'
      );
    }

    const sessionRef = db.collection("hafizSessions").doc();

    // ============================================
    // ✅ STEP 5: WRITE PHASE
    // ============================================
    const requestUpdateData = {
      status: STATUS.ACCEPTED,
      isPaid: true,
      paymentAmount: 0.0,
      promoCode,
      promoDiscount: 100,
      notificationsAlreadySent: true,
      sessionId: sessionRef.id,
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
        mohaffezName,
        sessionType,
        preferredTimeSlot,
        slotDate: slotDateTimestamp,
        slotStart: slotStartTimestamp,
        slotEnd: slotEndTimestamp,
        imamAddressText: imamAddressText || null,
        imamAddressLat: imamAddressLat || null,
        imamAddressLng: imamAddressLng || null,
        mohaffezPhone: mohaffezPhone || null,
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
    transaction.set(sessionRef, {
      requestId: requestRef.id,
      mohaffezId,
      studentId,
      mohaffezName,
      studentName,
      sessionType,
      location: imamAddressText || "",
      mohaffezPhone: mohaffezPhone || null,
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
      promoCode,
      paymentId: paymentId || null,
      createdAt: FieldValue.serverTimestamp(),
      acceptedAt: FieldValue.serverTimestamp(),
      reminder24hSent: false,
      reminder1hSent: false,
      juzCount: 1,
      sessionRating: 10,
    });

    functions.logger.info("📝 Creating hafizSession", {
      sessionId: sessionRef.id,
      requestId: requestRef.id,
    });

    // Update payment (if provided)
    if (paymentId) {
      const paymentRef = db.collection("payments").doc(paymentId);
      transaction.update(paymentRef, {
        status: "completed",
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        subscriptionId: sessionRef.id,
        notes: "Free session via promo code",
      });

      // Log payment event
      const eventRef = db.collection("paymentEvents").doc();
      transaction.set(eventRef, {
        eventId: eventRef.id,
        eventType: "payment_completed",
        paymentId: paymentId,
        userId: studentId,
        data: {
          amount: 0,
          method: "free",
          promoCode: promoCode,
          sessionId: sessionRef.id,
        },
        metadata: {
          source: "cloud_function",
          notes: "Free session confirmed via confirmFreeSession",
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    }

    // Increment promo code usage
    transaction.update(promoDoc.ref, {
      usedCount: FieldValue.increment(1),
      lastUsedAt: FieldValue.serverTimestamp(),
      lastUsedBy: studentId,
    });

    // Disable availability slot
    if (availabilityDoc) {
      const availabilityData = availabilityDoc.data();
      if (availabilityData && Array.isArray(availabilityData.timeSlots)) {
        const timeSlots = availabilityData.timeSlots;
        const normalizedSlot = preferredTimeSlot.replace(/ /g, "");

        const updatedSlots = timeSlots.map((slot: any) => {
          const slotTime = `${slot.startTime}-${slot.endTime}`.replace(/ /g, "");
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
      paymentId: paymentId || null,
      studentId,
      mohaffezId,
      promoCode,
      isUpdatingExisting,
      operation: isUpdatingExisting ? "UPDATE" : "CREATE",
      transactionComplete: true,
    });

    return {
      success: true,
      sessionId: sessionRef.id,
      requestId: requestRef.id,
      paymentId: paymentId || null,
      message: "تم إنشاء الجلسة المجانية بنجاح",
      isUpdatingExisting,  // ✅ Include in response
    };
  }).catch((error) => {
    // Handle "already-exists" pseudo-error (used for early return)
    if (error.code === "already-exists") {
      const result = JSON.parse(error.message);
      functions.logger.info("✅ Returning existing session (no duplicate created)", result);
      return result;
    }
    
    // ✅ LOG ANY OTHER ERRORS
    functions.logger.error("❌ Transaction failed", {
      errorCode: error.code,
      errorMessage: error.message,
      stack: error.stack,
    });
    
    throw error;
  });
});
