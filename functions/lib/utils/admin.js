"use strict";
// functions/src/utils/admin.ts
Object.defineProperty(exports, "__esModule", { value: true });
exports.FieldValue = exports.auth = exports.messaging = exports.db = void 0;
const admin = require("firebase-admin");
// Initialize Firebase Admin once
admin.initializeApp();
exports.db = admin.firestore();
exports.messaging = admin.messaging();
exports.auth = admin.auth();
exports.FieldValue = admin.firestore.FieldValue; // ✅ مضاف
exports.default = admin;
//# sourceMappingURL=admin.js.map