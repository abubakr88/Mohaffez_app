"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.triggerCleanupJobManually = exports.triggerCommissionJobManually = exports.sendBroadcastNotification = exports.deleteUserAccount = exports.suspendUser = exports.setUserRole = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const admin_1 = require("../utils/admin");
const commissions_1 = require("../payments/commissions");
const releaseExpiredSlotLocks_1 = require("../cleanup/releaseExpiredSlotLocks");
async function isAdminCaller(context) {
    var _a, _b;
    if (!((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid))
        return false;
    if (context.auth.token.admin === true)
        return true;
    const userDoc = await admin_1.db.collection('users').doc(context.auth.uid).get();
    return userDoc.exists && ((_b = userDoc.data()) === null || _b === void 0 ? void 0 : _b.role) === 'admin';
}
async function ensureAdmin(context) {
    var _a;
    if (!((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new functions.https.HttpsError('unauthenticated', '??? ????? ??????');
    }
    const ok = await isAdminCaller(context);
    if (!ok) {
        throw new functions.https.HttpsError('permission-denied', '??? ????');
    }
    return context.auth.uid;
}
async function writeAuditLog(params) {
    var _a, _b;
    await admin_1.db.collection('adminAuditLog').add({
        action: params.action,
        performedBy: params.performedBy,
        targetUserId: (_a = params.targetUserId) !== null && _a !== void 0 ? _a : null,
        data: (_b = params.data) !== null && _b !== void 0 ? _b : null,
        timestamp: admin_1.FieldValue.serverTimestamp(),
    });
}
/**
 * input: { userId: string, newRole: string }
 * output: { success: true }
 */
exports.setUserRole = functions.https.onCall(async (data, context) => {
    var _a, _b;
    const performedBy = await ensureAdmin(context);
    const userId = (_a = data === null || data === void 0 ? void 0 : data.userId) === null || _a === void 0 ? void 0 : _a.trim();
    const newRole = (_b = data === null || data === void 0 ? void 0 : data.newRole) === null || _b === void 0 ? void 0 : _b.trim();
    if (!userId || !newRole) {
        throw new functions.https.HttpsError('invalid-argument', '?????? ??? ??????');
    }
    await admin_1.auth.getUser(userId);
    await admin_1.db.collection('users').doc(userId).update({
        role: newRole,
        roleUpdatedAt: admin_1.FieldValue.serverTimestamp(),
        roleUpdatedBy: performedBy,
    });
    await writeAuditLog({
        action: 'setUserRole',
        performedBy,
        targetUserId: userId,
        data: { newRole },
    });
    functions.logger.info('Admin set user role', { performedBy, userId, newRole });
    return { success: true };
});
/**
 * input: { userId: string, reason: string, expiresAt?: string | null }
 * output: { success: true }
 */
exports.suspendUser = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    const performedBy = await ensureAdmin(context);
    const userId = (_a = data === null || data === void 0 ? void 0 : data.userId) === null || _a === void 0 ? void 0 : _a.trim();
    const reason = (_c = (_b = data === null || data === void 0 ? void 0 : data.reason) === null || _b === void 0 ? void 0 : _b.trim()) !== null && _c !== void 0 ? _c : '';
    const expiresAtRaw = data === null || data === void 0 ? void 0 : data.expiresAt;
    if (!userId || !reason) {
        throw new functions.https.HttpsError('invalid-argument', '??? ??????? ?????');
    }
    const userRecord = await admin_1.auth.getUser(userId);
    const expiresAt = expiresAtRaw ? admin.firestore.Timestamp.fromDate(new Date(expiresAtRaw)) : null;
    const batch = admin_1.db.batch();
    batch.update(admin_1.db.collection('users').doc(userId), {
        status: 'suspended',
        updatedAt: admin_1.FieldValue.serverTimestamp(),
    });
    batch.set(admin_1.db.collection('userSuspensions').doc(userId), {
        userId,
        suspendedBy: performedBy,
        reason,
        suspendedAt: admin_1.FieldValue.serverTimestamp(),
        expiresAt,
        isActive: true,
    }, { merge: true });
    await batch.commit();
    const configDoc = await admin_1.db.collection('systemConfig').doc('global').get();
    const fcmEnabled = ((_d = configDoc.data()) === null || _d === void 0 ? void 0 : _d.fcmEnabled) != false;
    const targetDoc = await admin_1.db.collection('users').doc(userId).get();
    const token = (_e = targetDoc.data()) === null || _e === void 0 ? void 0 : _e.fcmToken;
    if (fcmEnabled && token != null && token.length > 0) {
        await admin_1.messaging.send({
            token,
            notification: {
                title: '?? ????? ??????',
                body: reason,
            },
            data: {
                type: 'account_suspended',
                uid: userRecord.uid,
            },
        });
    }
    await writeAuditLog({
        action: 'suspendUser',
        performedBy,
        targetUserId: userId,
        data: { reason, expiresAt: expiresAtRaw !== null && expiresAtRaw !== void 0 ? expiresAtRaw : null },
    });
    functions.logger.info('Admin suspended user', { performedBy, userId });
    return { success: true };
});
/**
 * input: { userId: string }
 * output: { success: true }
 */
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
    var _a;
    const performedBy = await ensureAdmin(context);
    const userId = (_a = data === null || data === void 0 ? void 0 : data.userId) === null || _a === void 0 ? void 0 : _a.trim();
    if (!userId) {
        throw new functions.https.HttpsError('invalid-argument', 'userId ?????');
    }
    await admin_1.auth.getUser(userId);
    await admin_1.auth.deleteUser(userId);
    await admin_1.db.collection('users').doc(userId).delete();
    const studentPending = await admin_1.db
        .collection('sessionRequests')
        .where('studentId', '==', userId)
        .where('status', '==', 'pending')
        .get();
    const mohaffezPending = await admin_1.db
        .collection('sessionRequests')
        .where('mohaffezId', '==', userId)
        .where('status', '==', 'pending')
        .get();
    const batch = admin_1.db.batch();
    for (const doc of [...studentPending.docs, ...mohaffezPending.docs]) {
        batch.update(doc.ref, {
            status: 'cancelled',
            cancelledBy: performedBy,
            cancellationReason: 'admin_delete_user',
            updatedAt: admin_1.FieldValue.serverTimestamp(),
        });
    }
    await batch.commit();
    await writeAuditLog({
        action: 'deleteUserAccount',
        performedBy,
        targetUserId: userId,
    });
    functions.logger.info('Admin deleted user account', { performedBy, userId });
    return { success: true };
});
/**
 * input: { title: string, body: string, targetRole: 'all'|'student'|'mohaffez' }
 * output: { recipientCount: number }
 */
exports.sendBroadcastNotification = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    const performedBy = await ensureAdmin(context);
    const title = (_a = data === null || data === void 0 ? void 0 : data.title) === null || _a === void 0 ? void 0 : _a.trim();
    const body = (_b = data === null || data === void 0 ? void 0 : data.body) === null || _b === void 0 ? void 0 : _b.trim();
    const targetRole = ((_c = data === null || data === void 0 ? void 0 : data.targetRole) !== null && _c !== void 0 ? _c : 'all');
    if (!title || !body) {
        throw new functions.https.HttpsError('invalid-argument', '??????? ????? ???????');
    }
    let query = admin_1.db.collection('users');
    if (targetRole !== 'all') {
        query = query.where('role', '==', targetRole);
    }
    const usersSnap = await query.get();
    const tokens = [];
    for (const doc of usersSnap.docs) {
        const token = doc.data().fcmToken;
        if (token != null && token.length > 0)
            tokens.push(token);
    }
    const chunkSize = 500;
    for (let i = 0; i < tokens.length; i += chunkSize) {
        const chunk = tokens.slice(i, i + chunkSize);
        await admin_1.messaging.sendEachForMulticast({
            tokens: chunk,
            notification: { title, body },
            data: { type: 'broadcast', targetRole },
        });
    }
    await admin_1.db.collection('broadcastHistory').add({
        title,
        body,
        targetRole,
        sentAt: admin_1.FieldValue.serverTimestamp(),
        sentBy: performedBy,
        recipientCount: tokens.length,
    });
    await writeAuditLog({
        action: 'sendBroadcastNotification',
        performedBy,
        data: { title, targetRole, recipientCount: tokens.length },
    });
    functions.logger.info('Admin sent broadcast notification', {
        performedBy,
        targetRole,
        recipientCount: tokens.length,
    });
    return { recipientCount: tokens.length };
});
/**
 * input: {}
 * output: { processed: number }
 */
exports.triggerCommissionJobManually = functions.https.onCall(async (_, context) => {
    const performedBy = await ensureAdmin(context);
    const processed = await (0, commissions_1.processWeeklyCommissionsNow)();
    await writeAuditLog({
        action: 'triggerCommissionJobManually',
        performedBy,
        data: { processed },
    });
    functions.logger.info('Admin triggered commissions job', { performedBy, processed });
    return { processed };
});
/**
 * input: {}
 * output: { released: number }
 */
exports.triggerCleanupJobManually = functions.https.onCall(async (_, context) => {
    const performedBy = await ensureAdmin(context);
    const released = await (0, releaseExpiredSlotLocks_1.releaseExpiredSlotLocksNow)();
    await writeAuditLog({
        action: 'triggerCleanupJobManually',
        performedBy,
        data: { released },
    });
    functions.logger.info('Admin triggered cleanup job', { performedBy, released });
    return { released };
});
//# sourceMappingURL=adminActions.js.map