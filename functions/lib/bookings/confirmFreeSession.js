"use strict";
// functions/src/bookings/confirmFreeSession.ts
Object.defineProperty(exports, "__esModule", { value: true });
exports.confirmFreeSession = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const admin_1 = require("../utils/admin");
const EventStore_1 = require("../services/EventStore");
const STATUS = {
    PENDING: 'pending',
    AWAITING_PAYMENT: 'awaitingpayment',
    AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
    ACCEPTED: 'accepted',
    REJECTED: 'rejected',
    CANCELLED: 'cancelled',
};
// FIX-2: Parse Flutter ISO strings without timezone as UTC to prevent server-local shift
function parseFlutterDate(iso) {
    // If the string has no timezone info, treat it as UTC
    if (!iso.endsWith('Z') && !/[+\-]\d{2}:\d{2}$/.test(iso)) {
        return new Date(iso + 'Z');
    }
    return new Date(iso);
}
// FIXED: BUG-5 - strip both hyphens AND en-dashes
function normalizeTimeSlot(raw) {
    return raw.replace(/\s/g, '').replace(/[\u2013\u2014]/g, '-');
}
exports.confirmFreeSession = functions.https.onCall(async (data, context) => {
    var _a;
    functions.logger.info("🎫 confirmFreeSession v6.0 (17/2/2026) - Enhanced Logging");
    // 1. Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "المستخدم غير مصادق عليه");
    }
    const studentId = context.auth.uid;
    // 2. Validate input
    const { mohaffezId, mohaffezName, studentName, sessionType, preferredTimeSlot, slotDate, slotStart, slotEnd, imamAddressText, imamAddressLat, imamAddressLng, mohaffezPhone, promoCode, requestId, paymentId, } = data;
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
    if (!mohaffezId ||
        !mohaffezName ||
        !studentName ||
        !sessionType ||
        !preferredTimeSlot ||
        !slotDate ||
        !slotStart ||
        !slotEnd ||
        !promoCode) {
        throw new functions.https.HttpsError("invalid-argument", "بيانات غير مكتملة");
    }
    // 3. ✅ QUICK PRE-CHECK (non-blocking, advisory only)
    if (requestId) {
        const quickCheck = await admin_1.db
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
    const result = await admin_1.db.runTransaction(async (transaction) => {
        var _a;
        // FIX-1: Move promo code read/validation into transaction to avoid TOCTOU race
        const promoQuery = admin_1.db
            .collection("promoCodes")
            .where("code", "==", promoCode)
            .limit(1);
        const promoSnapshot = await transaction.get(promoQuery);
        if (promoSnapshot.empty) {
            throw new functions.https.HttpsError("not-found", "كود الخصم غير موجود");
        }
        const promoDoc = promoSnapshot.docs[0];
        const promoData = promoDoc.data();
        if (!promoData.isActive) {
            throw new functions.https.HttpsError("failed-precondition", "كود الخصم غير نشط");
        }
        if (promoData.discountPercent !== 100) {
            throw new functions.https.HttpsError("failed-precondition", "كود الخصم يجب أن يكون 100%");
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
        functions.logger.info("🔄 Transaction started");
        const slotDateTimestamp = admin.firestore.Timestamp.fromDate(parseFlutterDate(slotDate));
        const slotStartTimestamp = admin.firestore.Timestamp.fromDate(parseFlutterDate(slotStart));
        const slotEndTimestamp = admin.firestore.Timestamp.fromDate(parseFlutterDate(slotEnd));
        // ============================================
        // ✅ STEP 1: IDEMPOTENCY CHECK INSIDE TRANSACTION
        // ============================================
        // Check 1: By requestId
        if (requestId) {
            const existingByRequestQuery = admin_1.db
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
        if (paymentId) {
            const existingByPaymentQuery = admin_1.db
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
                return {
                    __idempotent: true,
                    success: true,
                    sessionId: session.id,
                    requestId: sessionData.requestId || null,
                    message: "الجلسة موجودة بالفعل",
                };
            }
        }
        // ============================================
        // ✅ STEP 2: CHECK FOR EXISTING SESSION ON THIS SLOT
        // ============================================
        const existingSessionOnSlotQuery = admin_1.db
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
            throw new functions.https.HttpsError("resource-exhausted", "هذا التوقيت محجوز بالفعل");
        }
        // ============================================
        // ✅ STEP 3: READ AVAILABILITY AND VERIFY SLOT IS ENABLED
        // ============================================
        const slotDateObj = parseFlutterDate(slotDate);
        const dayOfWeek = slotDateObj.getDay() === 0 ? 7 : slotDateObj.getDay();
        const availabilityQuery = admin_1.db
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
                    functions.logger.error("❌ Slot is disabled", {
                        mohaffezId,
                        dayOfWeek,
                        timeSlot: normalizedSlot,
                    });
                    throw new functions.https.HttpsError("failed-precondition", "هذا التوقيت غير متاح حالياً");
                }
            }
        }
        // ============================================
        // ✅ STEP 4: HANDLE REQUEST DOCUMENT
        // ============================================
        let requestRef;
        let isUpdatingExisting = false;
        if (requestId) {
            requestRef = admin_1.db.collection('sessionRequests').doc(requestId);
            const existingRequest = await transaction.get(requestRef);
            // ✅ LOG: Check if request exists
            functions.logger.info("🔍 Checking existing request document", {
                requestId,
                exists: existingRequest.exists,
                status: existingRequest.exists ? (_a = existingRequest.data()) === null || _a === void 0 ? void 0 : _a.status : "N/A",
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
                    return {
                        __idempotent: true,
                        success: true,
                        sessionId: sessionId,
                        requestId: requestId,
                        message: 'الجلسة مؤكدة بالفعل'
                    };
                }
            }
            isUpdatingExisting = true;
            // ✅ LOG: Will update existing request
            functions.logger.info("✅ Will UPDATE existing request", {
                requestId,
                currentStatus: requestData === null || requestData === void 0 ? void 0 : requestData.status,
                isUpdatingExisting: true,
            });
        }
        else {
            // ✅ LOG: No requestId provided
            functions.logger.error("❌ No requestId provided!", {
                studentId,
                mohaffezId,
                promoCode,
            });
            throw new functions.https.HttpsError('invalid-argument', 'معرف الطلب مطلوب للجلسات المجانية');
        }
        const sessionRef = admin_1.db.collection("hafizSessions").doc();
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
            acceptedAt: admin_1.FieldValue.serverTimestamp(),
            paidAt: admin_1.FieldValue.serverTimestamp(),
            updatedAt: admin_1.FieldValue.serverTimestamp(),
        };
        if (isUpdatingExisting) {
            // ✅ UPDATE existing request
            transaction.update(requestRef, requestUpdateData);
            functions.logger.info("📝 Updating existing sessionRequest", {
                requestId: requestRef.id,
                operation: "UPDATE",
            });
        }
        else {
            // ✅ CREATE new request
            transaction.set(requestRef, Object.assign(Object.assign({}, requestUpdateData), { studentId,
                mohaffezId,
                studentName,
                mohaffezName,
                sessionType,
                preferredTimeSlot, slotDate: slotDateTimestamp, slotStart: slotStartTimestamp, slotEnd: slotEndTimestamp, imamAddressText: imamAddressText || null, imamAddressLat: imamAddressLat || null, imamAddressLng: imamAddressLng || null, mohaffezPhone: mohaffezPhone || null, requiresPaymentOnAcceptance: false, selectedPaymentMethod: "freesession", createdAt: admin_1.FieldValue.serverTimestamp() }));
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
            createdAt: admin_1.FieldValue.serverTimestamp(),
            acceptedAt: admin_1.FieldValue.serverTimestamp(),
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
            const paymentRef = admin_1.db.collection("payments").doc(paymentId);
            transaction.update(paymentRef, {
                status: "completed",
                paidAt: admin_1.FieldValue.serverTimestamp(),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
                sessionId: sessionRef.id,
                notes: "Free session via promo code",
            });
        }
        // Increment promo code usage
        transaction.update(promoDoc.ref, {
            usedCount: admin_1.FieldValue.increment(1),
            lastUsedAt: admin_1.FieldValue.serverTimestamp(),
            lastUsedBy: studentId,
        });
        // Disable availability slot
        if (availabilityDoc) {
            const availabilityData = availabilityDoc.data();
            if (availabilityData && Array.isArray(availabilityData.timeSlots)) {
                const timeSlots = availabilityData.timeSlots;
                const normalizedSlot = normalizeTimeSlot(preferredTimeSlot);
                const updatedSlots = timeSlots.map((slot) => {
                    const slotTime = normalizeTimeSlot(`${slot.startTime}-${slot.endTime}`);
                    if (slotTime === normalizedSlot && slot.sessionType === sessionType && slot.enabled) {
                        return Object.assign(Object.assign({}, slot), { enabled: false });
                    }
                    return slot;
                });
                transaction.update(availabilityDoc.ref, {
                    timeSlots: updatedSlots,
                    updatedAt: admin_1.FieldValue.serverTimestamp(),
                });
                functions.logger.info("🔒 Availability slot disabled", {
                    mohaffezId,
                    dayOfWeek,
                    timeSlot: normalizedSlot,
                    sessionType,
                });
            }
        }
        else {
            functions.logger.warn("⚠️ No availability document found", {
                mohaffezId,
                dayOfWeek,
                slotDate,
            });
        }
        // Send notifications
        const notificationRef = admin_1.db.collection("notifications").doc();
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
            createdAt: admin_1.FieldValue.serverTimestamp(),
        });
        const mohaffezNotificationRef = admin_1.db.collection("notifications").doc();
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
            createdAt: admin_1.FieldValue.serverTimestamp(),
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
            isUpdatingExisting, // ✅ Include in response
        };
    });
    // FIX-CONFIRM-2: Handle idempotent early-returns cleanly without JSON.parse.
    if (result.__idempotent === true) {
        functions.logger.info('confirmFreeSession: returning existing session', result);
        return {
            success: result.success,
            sessionId: result.sessionId,
            requestId: result.requestId,
            paymentId: (_a = result.paymentId) !== null && _a !== void 0 ? _a : null,
            message: result.message,
        };
    }
    const { createAndSendNotification } = await Promise.resolve().then(() => require('../utils/notificationHelpers'));
    try {
        await Promise.all([
            createAndSendNotification({
                userId: studentId,
                senderId: mohaffezId,
                title: 'تم تأكيد جلستك المجانية ✅',
                body: `جلستك مع ${mohaffezName} مؤكدة.`,
                type: 'sessionconfirmed',
                highPriority: true,
                data: { sessionId: result.sessionId, requestId: result.requestId },
            }),
            createAndSendNotification({
                userId: mohaffezId,
                senderId: studentId,
                title: 'حجز جلسة مجانية جديد',
                body: `${studentName} حجز جلسة مجانية معك.`,
                type: 'sessionconfirmed',
                highPriority: true,
                data: { sessionId: result.sessionId, requestId: result.requestId },
            }),
        ]);
    }
    catch (notifError) {
        // FIX-CONFIRM-1: Log and enqueue for retry — do NOT crash the function.
        // The session is already confirmed; only the push notification failed.
        functions.logger.error('confirmFreeSession: post-transaction FCM failed', {
            sessionId: result.sessionId,
            requestId: result.requestId,
            studentId,
            mohaffezId,
            error: notifError instanceof Error ? notifError.message : String(notifError),
        });
        await admin_1.db.collection('failedOperations').add({
            operationType: 'notification-free-session',
            sessionId: result.sessionId,
            requestId: result.requestId,
            studentId,
            mohaffezId,
            error: notifError instanceof Error ? notifError.message : 'unknown',
            timestamp: admin_1.FieldValue.serverTimestamp(),
            retryCount: 0,
            status: 'pending-retry',
        });
    }
    // BUG #1 FIX: Call EventStore and update payment document after transaction commits
    // This ensures the payment event is properly recorded for analytics
    if (paymentId && paymentId.trim() !== '') {
        try {
            const eventStore = new EventStore_1.EventStore();
            await eventStore.appendFreeSessionCompletedEvent({
                paymentId: paymentId,
                userId: studentId,
                promoCode: promoCode,
            });
            functions.logger.info('EventStore: Free session completed event appended', { paymentId, studentId });
            // Also ensure payment document is marked as completed (idempotent update)
            await admin_1.db.collection('payments').doc(paymentId).update({
                status: 'completed',
                paidAt: admin_1.FieldValue.serverTimestamp(),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
            });
            functions.logger.info('Payment document marked as completed', { paymentId });
        }
        catch (eventStoreError) {
            // Do NOT throw - the session is already confirmed
            functions.logger.error('Failed to update payment status via EventStore (non-critical)', {
                paymentId,
                error: eventStoreError instanceof Error ? eventStoreError.message : String(eventStoreError),
            });
        }
    }
    return result;
});
//# sourceMappingURL=confirmFreeSession.js.map