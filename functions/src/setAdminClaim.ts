import * as functions from 'firebase-functions';
import { auth, db, FieldValue } from './utils/admin';
import {
  AdminRole,
  requireSuperAdminAccess,
  sanitizePermissionInput,
  SUPER_ADMIN_PERMISSIONS,
} from './utils/adminPermissions';

export const setAdminClaim = functions.https.onCall(async (data, context) => {
  const caller = await requireSuperAdminAccess(context);

  const targetUid = (data?.targetUid as string | undefined)?.trim();
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid is required');
  }

  const adminRoleRaw = (data?.adminRole as string | undefined)?.trim();
  const adminRole: AdminRole =
    adminRoleRaw === 'super_admin' ? 'super_admin' : 'admin';
  if (targetUid === caller.uid && adminRole !== 'super_admin') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'لا يمكن تقليل صلاحيات حسابك الحالي',
    );
  }
  const permissions =
    adminRole === 'super_admin'
      ? {}
      : sanitizePermissionInput(data?.permissions);

  await auth.setCustomUserClaims(targetUid, {
    admin: true,
    role: 'admin',
    adminRole,
    adminPermissions:
      adminRole === 'super_admin' ? SUPER_ADMIN_PERMISSIONS : permissions,
  });

  await db.collection('users').doc(targetUid).update({
    role: 'admin',
    adminRole,
    adminPermissions: permissions,
    adminAccessUpdatedAt: FieldValue.serverTimestamp(),
    adminAccessUpdatedBy: caller.uid,
    updatedAt: FieldValue.serverTimestamp(),
  });

  // WHY: Keep immutable traceability for privilege changes.
  await db.collection('adminAuditLog').add({
    action: 'set_admin_claim',
    targetUid,
    performedBy: caller.uid,
    data: { adminRole, permissions },
    timestamp: FieldValue.serverTimestamp(),
  });

  return { success: true };
});
