"use strict";
// functions/src/utils/admin.ts
Object.defineProperty(exports, "__esModule", { value: true });
exports.FieldValue = exports.auth = exports.messaging = exports.db = void 0;
const admin = require("firebase-admin");
// Initialize Firebase Admin once
admin.initializeApp();
// FIX-4: App Check note for dev/emulator troubleshooting:
// FIX-4: If callable functions fail with `unauthenticated`, confirm debug token
// FIX-4: `7D1EA276-D13C-4074-9C86-85BC04C8343E` is registered in Firebase Console
// FIX-4: (App Check -> Android app -> Manage debug tokens). Do not change logic here.
exports.db = admin.firestore();
exports.messaging = admin.messaging();
exports.auth = admin.auth();
exports.FieldValue = admin.firestore.FieldValue; // ✅ مضاف
exports.default = admin;
//# sourceMappingURL=admin.js.map