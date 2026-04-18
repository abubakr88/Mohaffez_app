"use strict";
// functions/src/payments/directPayment.ts
Object.defineProperty(exports, "__esModule", { value: true });
exports.mohaffezRejectDirectPayment = exports.mohaffezConfirmDirectPayment = exports.studentMarkedDirectPayment = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const admin_1 = require("../utils/admin");
const dateHelpers_1 = require("../utils/dateHelpers");
const STATUS = {
    PENDING: 'pending',
    AWAITING_PAYMENT: 'awaitingpayment',
    AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
    ACCEPTED: 'accepted',
    REJECTED: 'rejected',
    CANCELLED: 'cancelled',
};
// ─────────────────────────────────────────────────────────────────────────────
// 1. studentMarkedDirectPayment
// ─────────────────────────────────────────────────────────────────────────────
exports.studentMarkedDirectPayment = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    const studentId = context.auth.uid;
    const { requestId, mohaffezId, mohaffezName, studentName, amount, sessionType, preferredTimeSlot, slotDate, slotStart, slotEnd, paymentMethod, studentNote, imamAddressText, imamAddressLat, imamAddressLng, mohaffezPhone, planType, planId, planTitle, sessionsCount, validityDays, } = data;
    if (typeof requestId !== 'string' || requestId.trim().length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'requestId required');
    }
    const finalPlanType = (_a = planType) !== null && _a !== void 0 ? _a : 'single';
    const finalPlanId = (_b = planId) !== null && _b !== void 0 ? _b : null;
    const finalPlanTitle = (_c = planTitle) !== null && _c !== void 0 ? _c : null;
    const finalSessionsCount = typeof sessionsCount === 'number' ? sessionsCount : null;
    const finalValidityDays = typeof validityDays === 'number' ? validityDays : null;
    const isBundleOrSubscription = finalPlanType === 'bundle' || finalPlanType === 'subscription';
    const hasSlotFields = !!slotDate && !!slotStart && !!slotEnd && !!preferredTimeSlot;
    return admin_1.db.runTransaction(async (tx) => {
        var _a, _b, _c, _d;
        // ── READS ──
        const reqRef = admin_1.db.collection('sessionRequests').doc(requestId);
        const reqSnap = await tx.get(reqRef);
        if (!reqSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'Session request not found');
        }
        const reqData = reqSnap.data();
        if (reqData.status === STATUS.ACCEPTED) {
            throw new functions.https.HttpsError('already-exists', JSON.stringify({ success: true, message: 'Already confirmed' }));
        }
        if (reqData.status === STATUS.AWAITING_DIRECT) {
            throw new functions.https.HttpsError('already-exists', JSON.stringify({ success: true, message: 'Already marked as paid' }));
        }
        const isDirectPaymentPath = reqData.selectedPaymentMethod === 'directpayment';
        const acceptableStatuses = [STATUS.AWAITING_PAYMENT];
        if (isDirectPaymentPath)
            acceptableStatuses.push(STATUS.PENDING);
        if (!acceptableStatuses.includes(reqData.status)) {
            throw new functions.https.HttpsError('failed-precondition', `Cannot mark payment: request status is ${reqData.status}.`);
        }
        const configSnap = await tx.get(admin_1.db.collection('systemConfig').doc('global'));
        const commissionRate = (_b = (_a = configSnap.data()) === null || _a === void 0 ? void 0 : _a.commissionRate) !== null && _b !== void 0 ? _b : 0.05;
        const parsedSlotDate = (0, dateHelpers_1.parseFlutterDate)(slotDate);
        const parsedSlotStart = (0, dateHelpers_1.parseFlutterDate)(slotStart);
        const parsedSlotEnd = (0, dateHelpers_1.parseFlutterDate)(slotEnd);
        const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000));
        const newLockRef = admin_1.db.collection('slotLocks').doc();
        const bundleSlotLockId = newLockRef.id;
        const newReqRef = isBundleOrSubscription && hasSlotFields
            ? admin_1.db.collection('sessionRequests').doc()
            : null;
        const dpRef = admin_1.db.collection('directPaymentRequests').doc();
        // WRITE A: slotLock
        tx.set(newLockRef, {
            id: newLockRef.id,
            mohaffezId,
            slotDate: admin.firestore.Timestamp.fromDate(parsedSlotDate),
            timeSlot: preferredTimeSlot,
            sessionType,
            lockedBy: studentId,
            lockedAt: admin_1.FieldValue.serverTimestamp(),
            expiresAt,
            released: false,
            sessionRequestId: isBundleOrSubscription && hasSlotFields && newReqRef
                ? newReqRef.id
                : (_c = requestId) !== null && _c !== void 0 ? _c : null,
        });
        // WRITE B: new sessionRequest for bundle/subscription (slot-coupled only)
        if (isBundleOrSubscription && hasSlotFields && newReqRef) {
            tx.set(newReqRef, {
                id: newReqRef.id,
                status: STATUS.AWAITING_DIRECT,
                studentId,
                studentName,
                mohaffezId,
                mohaffezName,
                sessionType,
                preferredTimeSlot,
                slotDate: admin.firestore.Timestamp.fromDate(parsedSlotDate),
                slotStart: admin.firestore.Timestamp.fromDate(parsedSlotStart),
                slotEnd: admin.firestore.Timestamp.fromDate(parsedSlotEnd),
                planType: finalPlanType,
                planId: finalPlanId,
                planTitle: finalPlanTitle,
                sessionsCount: finalSessionsCount,
                validityDays: finalValidityDays,
                isPaid: false,
                selectedPaymentMethod: 'directpayment',
                directPaymentRequestId: null,
                slotLockId: newLockRef.id,
                paymentAmount: amount,
                requiresPaymentOnAcceptance: false,
                createdAt: admin_1.FieldValue.serverTimestamp(),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
            });
        }
        // WRITE C: directPaymentRequest
        tx.set(dpRef, {
            id: dpRef.id,
            // When this is a bundle/subscription purchase AND slot fields are present AND newReqRef exists:
            // - sessionRequestId  → newReqRef.id  (the new slot-lock sessionRequest)
            //   WHY: confirmBundleDirectPayment Step 9h updates dp.sessionRequestId → 'accepted',
            //        which removes req-B from the teacher's inbox. Step 9k reads slotLockId from it.
            // - originalSessionRequestId → requestId  (the original request from the client)
            //   WHY: confirmBundleDirectPayment Step 9h-b resolves req-A using this field.
            //
            // When this is a single-session purchase OR no slot fields OR no newReqRef:
            // - sessionRequestId  → requestId  (no change from current behavior)
            // - originalSessionRequestId → requestId  (same, Step 9h-b skips when equal)
            sessionRequestId: (isBundleOrSubscription && hasSlotFields && newReqRef)
                ? newReqRef.id
                : requestId,
            originalSessionRequestId: requestId,
            studentId,
            studentName,
            mohaffezId,
            mohaffezName,
            amount,
            commissionAmount: amount * commissionRate,
            commissionRate,
            sessionType,
            preferredTimeSlot,
            sessionDate: admin.firestore.Timestamp.fromDate(parsedSlotDate),
            slotStart: admin.firestore.Timestamp.fromDate(parsedSlotStart),
            slotEnd: admin.firestore.Timestamp.fromDate(parsedSlotEnd),
            imamAddressText: imamAddressText !== null && imamAddressText !== void 0 ? imamAddressText : null,
            imamAddressLat: imamAddressLat !== null && imamAddressLat !== void 0 ? imamAddressLat : null,
            imamAddressLng: imamAddressLng !== null && imamAddressLng !== void 0 ? imamAddressLng : null,
            mohaffezPhone: mohaffezPhone !== null && mohaffezPhone !== void 0 ? mohaffezPhone : null,
            paymentMethod,
            studentNote: studentNote !== null && studentNote !== void 0 ? studentNote : null,
            status: 'pendingconfirmation',
            studentConfirmedAt: admin_1.FieldValue.serverTimestamp(),
            mohaffezConfirmedAt: null,
            sessionId: null,
            createdAt: admin_1.FieldValue.serverTimestamp(),
            updatedAt: admin_1.FieldValue.serverTimestamp(),
            planType: finalPlanType,
            planId: finalPlanId,
            planTitle: finalPlanTitle,
            sessionsCount: finalSessionsCount,
            validityDays: finalValidityDays,
        });
        // WRITE D: update existing sessionRequest
        tx.update(reqRef, {
            status: STATUS.AWAITING_DIRECT,
            directPaymentRequestId: dpRef.id,
            slotLockId: (_d = newLockRef === null || newLockRef === void 0 ? void 0 : newLockRef.id) !== null && _d !== void 0 ? _d : null,
            directPaymentMethod: paymentMethod,
            updatedAt: admin_1.FieldValue.serverTimestamp(),
        });
        // WRITE E: link bundle sessionRequest back to dpRef (slot-coupled only)
        if (isBundleOrSubscription && hasSlotFields && newReqRef) {
            tx.update(newReqRef, {
                directPaymentRequestId: dpRef.id,
            });
        }
        // WRITE F: notification to mohaffez
        const notifRef = admin_1.db.collection('notifications').doc();
        tx.set(notifRef, {
            userId: mohaffezId,
            recipientId: mohaffezId,
            senderId: studentId,
            title: isBundleOrSubscription ? 'طلب دفع حزمة جديد' : 'طلب تأكيد دفع مباشر',
            body: isBundleOrSubscription
                ? `${studentName} حوّل ${amount} جنيه لـ ${finalPlanTitle} (${finalSessionsCount} جلسة) عبر ${paymentMethod}`
                : `${studentName} حوّل ${amount} جنيه عبر ${paymentMethod}`,
            type: 'directpaymentpending',
            isRead: false,
            data: {
                directPaymentRequestId: dpRef.id,
                sessionRequestId: requestId,
                studentId,
                studentName,
                amount: amount.toString(),
                paymentMethod,
                planType: finalPlanType,
                planId: finalPlanId,
                planTitle: finalPlanTitle,
                sessionsCount: finalSessionsCount,
                validityDays: finalValidityDays,
            },
            createdAt: admin_1.FieldValue.serverTimestamp(),
        });
        return {
            success: true,
            directPaymentRequestId: dpRef.id,
            sessionRequestId: requestId,
            slotLockId: bundleSlotLockId,
        };
    });
});
// ─────────────────────────────────────────────────────────────────────────────
// 2. mohaffezConfirmDirectPayment  ← FIXED: Bug1 + Bug2
// ─────────────────────────────────────────────────────────────────────────────
exports.mohaffezConfirmDirectPayment = functions.https.onCall(async (data, context) => {
    var _a;
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    const mohaffezId = context.auth.uid;
    const callerDoc = await admin_1.db.collection('users').doc(mohaffezId).get();
    if (!callerDoc.exists || ((_a = callerDoc.data()) === null || _a === void 0 ? void 0 : _a.role) !== 'mohaffez') {
        throw new functions.https.HttpsError('permission-denied', 'Caller must be a mohaffez');
    }
    const { directPaymentRequestId } = data;
    if (!directPaymentRequestId) {
        throw new functions.https.HttpsError('invalid-argument', 'directPaymentRequestId required');
    }
    // ✅ FIX Bug2: try/catch instead of .catch() so raw errors are wrapped
    //    with their actual message, and HttpsErrors are re-thrown as-is.
    try {
        return await admin_1.db.runTransaction(async (tx) => {
            var _a, _b, _c, _d, _e, _f, _g, _h;
            // ── READS ──
            const dpRef = admin_1.db.collection('directPaymentRequests').doc(directPaymentRequestId);
            const dpSnap = await tx.get(dpRef);
            if (!dpSnap.exists) {
                throw new functions.https.HttpsError('not-found', 'Payment request not found');
            }
            const dp = dpSnap.data();
            if (dp.mohaffezId !== mohaffezId) {
                throw new functions.https.HttpsError('permission-denied', 'This payment is not for you');
            }
            if (dp.status === 'confirmed') {
                throw new functions.https.HttpsError('already-exists', JSON.stringify({ success: true, sessionId: dp.sessionId, message: 'Already confirmed' }));
            }
            const sessionRequestId = dp.sessionRequestId;
            if (!sessionRequestId || sessionRequestId.trim().length === 0) {
                throw new functions.https.HttpsError('failed-precondition', 'directPaymentRequests doc is missing sessionRequestId.');
            }
            const reqRef = admin_1.db.collection('sessionRequests').doc(sessionRequestId);
            const reqSnap = await tx.get(reqRef);
            if (!reqSnap.exists) {
                throw new functions.https.HttpsError('not-found', 'sessionRequest not found');
            }
            const reqData = reqSnap.data();
            const reqSessionType = reqData.sessionType;
            if (!reqSessionType || reqSessionType.trim().length === 0) {
                throw new functions.https.HttpsError('failed-precondition', 'sessionRequest is missing sessionType.');
            }
            if (reqData.status === STATUS.ACCEPTED) {
                throw new functions.https.HttpsError('already-exists', JSON.stringify({ success: true, message: 'Session already accepted' }));
            }
            const configSnap = await tx.get(admin_1.db.collection('systemConfig').doc('global'));
            const commissionRate = (_b = (_a = configSnap.data()) === null || _a === void 0 ? void 0 : _a.commissionRate) !== null && _b !== void 0 ? _b : 0.05;
            // ✅ FIX Bug1: instanceof guard before .toDate() — prevents TypeError → INTERNAL
            if (!(dp.sessionDate instanceof admin.firestore.Timestamp)) {
                throw new functions.https.HttpsError('failed-precondition', 'directPaymentRequests doc has invalid or missing sessionDate.');
            }
            const sessionDate = dp.sessionDate;
            const sessionDateObj = sessionDate.toDate(); // ✅ safe
            const weekNumber = (0, dateHelpers_1.getWeekNumber)(sessionDateObj);
            const year = sessionDateObj.getFullYear();
            const summaryId = `${mohaffezId}_${year}_w${weekNumber}`;
            const summaryRef = admin_1.db.collection('weeklyCommissionSummaries').doc(summaryId);
            const summarySnap = await tx.get(summaryRef);
            // ── WRITES ──
            const sessionRef = admin_1.db.collection('hafizSessions').doc();
            const slotStart = dp.slotStart;
            const slotEnd = dp.slotEnd;
            tx.set(sessionRef, {
                requestId: (_c = dp.sessionRequestId) !== null && _c !== void 0 ? _c : null,
                mohaffezId,
                studentId: dp.studentId,
                mohaffezName: dp.mohaffezName,
                studentName: dp.studentName,
                sessionType: dp.sessionType,
                preferredTimeSlot: dp.preferredTimeSlot,
                sessionDate,
                slotStart,
                slotEnd,
                status: 'accepted',
                isPaid: true,
                sessionPrice: dp.amount,
                paymentType: 'directpayment',
                directPaymentRequestId,
                mohaffezPhone: (_d = dp.mohaffezPhone) !== null && _d !== void 0 ? _d : null,
                imamAddressText: (_e = dp.imamAddressText) !== null && _e !== void 0 ? _e : null,
                imamAddressLat: (_f = dp.imamAddressLat) !== null && _f !== void 0 ? _f : null,
                imamAddressLng: (_g = dp.imamAddressLng) !== null && _g !== void 0 ? _g : null,
                createdAt: admin_1.FieldValue.serverTimestamp(),
                acceptedAt: admin_1.FieldValue.serverTimestamp(),
                reminder24hSent: false,
                reminder1hSent: false,
                juzCount: 1,
                sessionRating: 10,
                notificationsAlreadySent: true,
            });
            tx.update(dpRef, {
                status: 'confirmed',
                sessionId: sessionRef.id,
                mohaffezConfirmedAt: admin_1.FieldValue.serverTimestamp(),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
            });
            tx.update(reqRef, {
                status: STATUS.ACCEPTED,
                isPaid: true,
                paidAt: admin_1.FieldValue.serverTimestamp(),
                sessionId: sessionRef.id,
                directPaymentConfirmedAt: admin_1.FieldValue.serverTimestamp(),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
            });
            const commissionAmount = dp.amount * commissionRate;
            const weekStart = (0, dateHelpers_1.getWeekStart)(sessionDateObj);
            const weekEnd = (0, dateHelpers_1.getWeekEnd)(sessionDateObj);
            const dueDate = (0, dateHelpers_1.getNextMonday)(sessionDateObj);
            if (summarySnap.exists) {
                tx.update(summaryRef, {
                    totalSessions: admin_1.FieldValue.increment(1),
                    totalRevenue: admin_1.FieldValue.increment(dp.amount),
                    commissionAmount: admin_1.FieldValue.increment(commissionAmount),
                    updatedAt: admin_1.FieldValue.serverTimestamp(),
                });
            }
            else {
                tx.set(summaryRef, {
                    mohaffezId,
                    mohaffezName: dp.mohaffezName,
                    weekNumber,
                    year,
                    totalSessions: 1,
                    totalRevenue: dp.amount,
                    commissionAmount,
                    commissionRate,
                    status: 'pending',
                    weekStart: admin.firestore.Timestamp.fromDate(weekStart),
                    weekEnd: admin.firestore.Timestamp.fromDate(weekEnd),
                    dueDate: admin.firestore.Timestamp.fromDate(dueDate),
                    createdAt: admin_1.FieldValue.serverTimestamp(),
                    updatedAt: admin_1.FieldValue.serverTimestamp(),
                });
            }
            const notifRef = admin_1.db.collection('notifications').doc();
            tx.set(notifRef, {
                userId: dp.studentId,
                recipientId: dp.studentId,
                senderId: mohaffezId,
                title: 'تم تأكيد الدفع المباشر!',
                body: `${dp.mohaffezName} أكد استلام المبلغ! تم تأكيد جلستك تلقائياً`,
                type: 'directpaymentconfirmed',
                isRead: false,
                data: {
                    sessionId: sessionRef.id,
                    sessionRequestId: (_h = dp.sessionRequestId) !== null && _h !== void 0 ? _h : null,
                    directPaymentRequestId,
                },
                createdAt: admin_1.FieldValue.serverTimestamp(),
            });
            return {
                success: true,
                sessionId: sessionRef.id,
                message: 'تم تأكيد الدفع! تم إنشاء الجلسة تلقائياً',
            };
        });
    }
    catch (error) {
        // ✅ FIX Bug2 (continued): idempotency shortcut
        if (error.code === 'already-exists') {
            return JSON.parse(error.message);
        }
        // Re-throw HttpsErrors as-is — never let Firebase wrap them as 'internal'
        if (error instanceof functions.https.HttpsError)
            throw error;
        // Wrap raw errors so the real message surfaces on the client
        const message = error instanceof Error ? error.message : 'Unknown error';
        functions.logger.error('mohaffezConfirmDirectPayment failed', {
            directPaymentRequestId,
            message,
            error,
        });
        throw new functions.https.HttpsError('internal', message);
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// 3. mohaffezRejectDirectPayment  ← unchanged
// ─────────────────────────────────────────────────────────────────────────────
exports.mohaffezRejectDirectPayment = functions.https.onCall(async (data, context) => {
    var _a;
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    const mohaffezId = context.auth.uid;
    const callerDoc = await admin_1.db.collection('users').doc(mohaffezId).get();
    if (!callerDoc.exists || ((_a = callerDoc.data()) === null || _a === void 0 ? void 0 : _a.role) !== 'mohaffez') {
        throw new functions.https.HttpsError('permission-denied', 'Caller must be a mohaffez');
    }
    const { directPaymentRequestId, rejectionReason } = data;
    if (!directPaymentRequestId) {
        throw new functions.https.HttpsError('invalid-argument', 'directPaymentRequestId required');
    }
    return admin_1.db
        .runTransaction(async (tx) => {
        var _a;
        // ── READS ──
        const dpRef = admin_1.db.collection('directPaymentRequests').doc(directPaymentRequestId);
        const dpSnap = await tx.get(dpRef);
        if (!dpSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'Payment request not found');
        }
        const dp = dpSnap.data();
        if (dp.mohaffezId !== mohaffezId) {
            throw new functions.https.HttpsError('permission-denied', 'This payment is not for you');
        }
        if (dp.status === 'confirmed') {
            throw new functions.https.HttpsError('failed-precondition', 'Cannot reject confirmed payment');
        }
        if (dp.status === 'rejected') {
            throw new functions.https.HttpsError('already-exists', JSON.stringify({ success: true, message: 'Already rejected' }));
        }
        let reqRef = null;
        if (dp.sessionRequestId) {
            reqRef = admin_1.db.collection('sessionRequests').doc(dp.sessionRequestId);
            await tx.get(reqRef); // must read before write in Firestore transactions
        }
        // ── WRITES ──
        tx.update(dpRef, {
            status: 'rejected',
            rejectionReason: rejectionReason !== null && rejectionReason !== void 0 ? rejectionReason : null,
            mohaffezRejectedAt: admin_1.FieldValue.serverTimestamp(),
            updatedAt: admin_1.FieldValue.serverTimestamp(),
        });
        if (reqRef) {
            const rejectedPlanType = typeof dp.planType === 'string' ? dp.planType : 'single';
            const isRejectedBundlePlan = rejectedPlanType === 'bundle' || rejectedPlanType === 'subscription';
            tx.update(reqRef, {
                status: isRejectedBundlePlan ? STATUS.PENDING : STATUS.AWAITING_PAYMENT,
                directPaymentRequestId: null,
                directPaymentRejectedAt: admin_1.FieldValue.serverTimestamp(),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
            });
        }
        // FIX[BUNDLE-ORPHAN]: Also reset the original session request (Request A) on rejection
        const originalSessionRequestId = dp.originalSessionRequestId;
        if (originalSessionRequestId &&
            originalSessionRequestId !== dp.sessionRequestId) {
            const originalReqRef = admin_1.db.collection('sessionRequests').doc(originalSessionRequestId);
            const originalReqSnap = await tx.get(originalReqRef);
            if (originalReqSnap.exists) {
                const prevStatus = (_a = originalReqSnap.data()) === null || _a === void 0 ? void 0 : _a.status;
                const resolvableOnReject = [
                    'awaitingdirectpaymentconfirmation',
                    'awaitingPayment',
                    'pending',
                ];
                if (prevStatus && resolvableOnReject.includes(prevStatus)) {
                    tx.update(originalReqRef, {
                        status: STATUS.PENDING,
                        directPaymentRequestId: null,
                        directPaymentRejectedAt: admin_1.FieldValue.serverTimestamp(),
                        updatedAt: admin_1.FieldValue.serverTimestamp(),
                    });
                }
            }
        }
        const notifRef = admin_1.db.collection('notifications').doc();
        tx.set(notifRef, {
            userId: dp.studentId,
            recipientId: dp.studentId,
            senderId: mohaffezId,
            title: 'تم رفض الدفع',
            body: rejectionReason
                ? `${dp.mohaffezName} رفض الدفع: ${rejectionReason}`
                : `${dp.mohaffezName} لم يتمكن من تأكيد استلام المبلغ`,
            type: 'directpaymentrejected',
            isRead: false,
            data: {
                sessionRequestId: dp.sessionRequestId,
                directPaymentRequestId,
            },
            createdAt: admin_1.FieldValue.serverTimestamp(),
        });
        return { success: true, message: 'تم رفض الدفع' };
    })
        .catch((e) => {
        if (e.code === 'already-exists') {
            return JSON.parse(e.message);
        }
        throw e;
    });
});
//# sourceMappingURL=directPayment.js.map