"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkMaintenanceMode = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
/**
 * input: {}
 * output: { inMaintenance: false }
 */
exports.checkMaintenanceMode = functions.https.onCall(async (_, context) => {
    var _a, _b;
    const uid = (_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid;
    const doc = await admin_1.db.collection('systemConfig').doc('global').get();
    const data = (_b = doc.data()) !== null && _b !== void 0 ? _b : {};
    const maintenanceMode = data.maintenanceMode === true;
    const allowed = Array.isArray(data.maintenanceAllowedUids)
        ? data.maintenanceAllowedUids
        : [];
    if (maintenanceMode && (!uid || !allowed.includes(uid))) {
        throw new functions.https.HttpsError('unavailable', 'maintenance');
    }
    return { inMaintenance: false };
});
//# sourceMappingURL=maintenanceCheck.js.map