// functions/src/utils/admin.ts

import * as admin from 'firebase-admin';

// Initialize Firebase Admin once
admin.initializeApp();

export const db = admin.firestore();
export const messaging = admin.messaging();
export const auth = admin.auth();
export const FieldValue = admin.firestore.FieldValue; // ✅ مضاف
export default admin;
