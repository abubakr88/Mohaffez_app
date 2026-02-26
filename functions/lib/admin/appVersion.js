"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkVersion = void 0;
// src/admin/appVersion.ts
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
exports.checkVersion = functions.https.onCall(async (data, context) => {
    const snap = await admin_1.db.collection('appVersions').doc('current').get();
    if (!snap.exists)
        return { forceUpdate: false, recommendedUpdate: false };
    return snap.data();
});
//# sourceMappingURL=appVersion.js.map