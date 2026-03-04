// src/admin/appVersion.ts
import * as functions from 'firebase-functions';
import { db } from '../utils/admin';

export const checkVersion = functions.https.onCall(async (data, context) => {
  const snap = await db.collection('appVersions').doc('current').get();
  if (!snap.exists) return { forceUpdate: false, recommendedUpdate: false };
  // FIXED: BUG-8 - invoke snap.data() as a method, not property
  return snap.data() ?? {};
});
