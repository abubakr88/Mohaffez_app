"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onUserUnsuspended = void 0;
const admin = require("firebase-admin");
const functions = require("firebase-functions");
const db = admin.firestore();
function asString(value) {
    return typeof value === 'string' ? value : '';
}
async function sendUnsuspendedNotification(uid) {
    var _a;
    const userDoc = await db.collection('users').doc(uid).get();
    const userData = (_a = userDoc.data()) !== null && _a !== void 0 ? _a : {};
    const fcmToken = asString(userData.fcmToken);
    if (!fcmToken)
        return;
    await admin.messaging().send({
        token: fcmToken,
        notification: {
            title: 'تم رفع التقييد عن حسابك',
            body: 'يمكنك الآن استخدام التطبيق بشكل طبيعي',
        },
        data: {
            type: 'account_unsuspended',
            uid,
        },
    });
}
async function restoreMohaffezAvailability(uid) {
    var _a;
    const userDoc = await db.collection('users').doc(uid).get();
    const role = asString((_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.role);
    if (role !== 'mohaffez')
        return;
    const availabilityDocs = await db.collection('users').doc(uid).collection('availability').get();
    for (let i = 0; i < availabilityDocs.docs.length; i += 400) {
        const batch = db.batch();
        const chunk = availabilityDocs.docs.slice(i, i + 400);
        for (const doc of chunk) {
            const data = doc.data();
            const rawSlots = Array.isArray(data.timeSlots) ? data.timeSlots : [];
            const updatedSlots = rawSlots.map((slot) => {
                const asMap = (slot && typeof slot === 'object' ? slot : {});
                if (asMap.disabledBySuspension == true) {
                    return Object.assign(Object.assign({}, asMap), { enabled: true, disabledBySuspension: false });
                }
                return asMap;
            });
            batch.update(doc.ref, {
                timeSlots: updatedSlots,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        await batch.commit();
    }
}
exports.onUserUnsuspended = functions.firestore
    .document('userSuspensions/{uid}')
    .onDelete(async (_snap, context) => {
    const uid = asString(context.params.uid);
    await sendUnsuspendedNotification(uid);
    await restoreMohaffezAvailability(uid);
    // WHY: Keep auditable restore trail for admin moderation actions.
    await db.collection('adminAuditLog').add({
        action: 'user_unsuspended',
        targetUid: uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
});
//# sourceMappingURL=onUserUnsuspended.js.map