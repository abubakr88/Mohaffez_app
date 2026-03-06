import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

export const setAdminClaim = functions.https.onCall(async (data, context) => {
  // WHY: Restrict claim elevation to authenticated callers only.
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();

  // WHY: Verify caller admin status from Firestore before promoting another account.
  if (callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Caller is not an admin');
  }

  const { targetUid } = data as { targetUid: string };
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid is required');
  }

  await admin.auth().setCustomUserClaims(targetUid, { role: 'admin' });

  // WHY: Keep immutable traceability for admin privilege changes.
  await admin.firestore().collection('adminAuditLog').add({
    action: 'set_admin_claim',
    targetUid,
    performedBy: context.auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});
