"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkVersion = void 0;
// src/admin/appVersion.ts
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
exports.checkVersion = functions.https.onCall(async (data, context) => {
    var _a;
    const snap = await admin_1.db.collection('appVersions').doc('current').get();
    if (!snap.exists)
        return { forceUpdate: false, recommendedUpdate: false };
    // FIXED: BUG-8 - invoke snap.data() as a method, not property
    return (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
});
//# sourceMappingURL=appVersion.js.map