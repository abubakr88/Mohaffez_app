"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.setAdminClaim = void 0;
const functions = require("firebase-functions");
const admin_1 = require("./utils/admin");
exports.setAdminClaim = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    // WHY: Restrict privilege elevation to authenticated callers only.
    if (!((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    const callerDoc = await admin_1.db.collection('users').doc(context.auth.uid).get();
    // WHY: Only existing admins can assign admin custom claims.
    if (((_b = callerDoc.data()) === null || _b === void 0 ? void 0 : _b.role) !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Caller is not an admin');
    }
    const targetUid = (_c = data === null || data === void 0 ? void 0 : data.targetUid) === null || _c === void 0 ? void 0 : _c.trim();
    if (!targetUid) {
        throw new functions.https.HttpsError('invalid-argument', 'targetUid is required');
    }
    await admin_1.auth.setCustomUserClaims(targetUid, { admin: true, role: 'admin' });
    // WHY: Keep immutable traceability for privilege changes.
    await admin_1.db.collection('adminAuditLog').add({
        action: 'set_admin_claim',
        targetUid,
        performedBy: context.auth.uid,
        timestamp: admin_1.FieldValue.serverTimestamp(),
    });
    return { success: true };
});
//# sourceMappingURL=setAdminClaim.js.map