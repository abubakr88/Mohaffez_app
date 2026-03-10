"use strict";
// functions/src/payments/confirmBundleDirectPayment.ts
// BUG #2: Confirm bundle/subscription purchase via direct cash payment
Object.defineProperty(exports, "__esModule", { value: true });
exports.confirmBundleDirectPayment = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const handlers_1 = require("./handlers");
const notificationHelpers_1 = require("../utils/notificationHelpers");
exports.confirmBundleDirectPayment = functions.https.onCall(async (data, context) => {
    functions.logger.info('confirmBundleDirectPayment: Starting', { timestamp: new Date().toISOString() });
    // 1. Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'المستخدم غير مصادق عليه');
    }
    const mohaffezId = context.auth.uid;
    // 2. Verify caller is the mohaffez
    if (context.auth.uid !== data.mohaffezId) {
        throw new functions.https.HttpsError('permission-denied', 'غير مصرح لك بتأكيد هذا الدفع');
    }
    // Extract input data
    const { paymentId, studentId, planId, planTitle, planType, sessionsCount, validityDays, amount, } = data;
    // Validate required fields
    if (!paymentId || !studentId || !mohaffezId || !planId || !planTitle || !planType || !sessionsCount || !amount) {
        throw new functions.https.HttpsError('invalid-argument', 'بيانات غير مكتملة');
    }
    try {
        // 3. Read the payments/{paymentId} document
        const paymentRef = admin_1.db.collection('payments').doc(paymentId);
        const paymentSnap = await paymentRef.get();
        if (!paymentSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'دفع غير موجود');
        }
        const paymentDoc = paymentSnap.data();
        // 4. Idempotency guard - if already completed, return success
        if (paymentDoc.status === 'completed' && paymentDoc.subscriptionId) {
            functions.logger.info('confirmBundleDirectPayment: Already confirmed (idempotent)', {
                paymentId,
                subscriptionId: paymentDoc.subscriptionId,
            });
            return {
                success: true,
                subscriptionId: paymentDoc.subscriptionId,
                message: 'Already confirmed',
            };
        }
        // 5. Verify payment status is pending
        if (paymentDoc.status !== 'pending') {
            throw new functions.https.HttpsError('failed-precondition', `Payment status is '${paymentDoc.status}', expected 'pending'`);
        }
        // 6. Verify studentId matches
        if (paymentDoc.studentId !== studentId) {
            throw new functions.https.HttpsError('permission-denied', 'معرف الطالب غير متطابق');
        }
        // 7. Verify amount matches
        if (paymentDoc.amount !== amount) {
            throw new functions.https.HttpsError('failed-precondition', 'Amount mismatch');
        }
        // 8. Build PaymentDocument object
        const paymentWithMeta = Object.assign(Object.assign({}, paymentDoc), { metadata: {
                planId,
                planTitle,
                planType,
                sessionsCount,
                validityDays,
            } });
        // 9. Build metadata for subscription creation
        const metadata = {
            planId,
            planTitle,
            planType,
            sessionsCount,
            validityDays,
        };
        // 10. Add metadata to payment document
        paymentWithMeta.metadata = metadata;
        // 11. Generate transaction ID
        const transactionId = `direct_bundle_${paymentId}_${Date.now()}`;
        // 12. Create subscription and mark payment as completed atomically
        const result = await (0, handlers_1.createSubscriptionFromPayment)(paymentWithMeta, transactionId, { paymentId, transactionId });
        functions.logger.info('confirmBundleDirectPayment: Subscription created', {
            paymentId,
            subscriptionId: result.subscriptionId,
        });
        // 13. Update payment document with subscriptionId (additional update outside the transaction)
        await paymentRef.update({
            subscriptionId: result.subscriptionId,
            updatedAt: admin_1.FieldValue.serverTimestamp(),
        });
        // 14. Send notification to student
        await (0, notificationHelpers_1.createAndSendNotification)({
            userId: studentId,
            senderId: mohaffezId,
            title: 'تم تفعيل باقتك',
            body: `تم تأكيد الدفع وتفعيل باقة ${data.planTitle} بنجاح.`,
            type: 'subscription_created',
            highPriority: true,
            data: {
                subscriptionId: result.subscriptionId,
                planTitle: data.planTitle,
                sessionsCount: String(data.sessionsCount),
            },
        });
        functions.logger.info('confirmBundleDirectPayment: Completed successfully', {
            paymentId,
            subscriptionId: result.subscriptionId,
        });
        // 15. Return success
        return {
            success: true,
            subscriptionId: result.subscriptionId,
        };
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        functions.logger.error('confirmBundleDirectPayment failed', {
            paymentId,
            error: message,
        });
        throw new functions.https.HttpsError('internal', message);
    }
});
//# sourceMappingURL=confirmBundleDirectPayment.js.map