import * as functions from 'firebase-functions';
import { auth, db, FieldValue } from './utils/admin';

export const setAdminClaim = functions.https.onCall(async (data, context) => {
  // WHY: Restrict privilege elevation to authenticated callers only.
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const callerDoc = await db.collection('users').doc(context.auth.uid).get();

  // WHY: Only existing admins can assign admin custom claims.
  if (callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Caller is not an admin');
  }

  const targetUid = (data?.targetUid as string | undefined)?.trim();
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid is required');
  }

  await auth.setCustomUserClaims(targetUid, { role: 'admin' });

  // WHY: Keep immutable traceability for privilege changes.
  await db.collection('adminAuditLog').add({
    action: 'set_admin_claim',
    targetUid,
    performedBy: context.auth.uid,
    timestamp: FieldValue.serverTimestamp(),
  });

  return { success: true };
});
