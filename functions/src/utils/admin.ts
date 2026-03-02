// functions/src/utils/admin.ts

import * as admin from 'firebase-admin';

// Initialize Firebase Admin once
admin.initializeApp();
// FIX-4: App Check note for dev/emulator troubleshooting:
// FIX-4: If callable functions fail with `unauthenticated`, confirm debug token
// FIX-4: `7D1EA276-D13C-4074-9C86-85BC04C8343E` is registered in Firebase Console
// FIX-4: (App Check -> Android app -> Manage debug tokens). Do not change logic here.

export const db = admin.firestore();
export const messaging = admin.messaging();
export const auth = admin.auth();
export const FieldValue = admin.firestore.FieldValue; // ✅ مضاف
export default admin;
