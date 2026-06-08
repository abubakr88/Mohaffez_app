import * as functions from 'firebase-functions';
import { auth, db, FieldValue } from './utils/admin';
import {
  AdminRole,
  requireSuperAdminAccess,
  sanitizePermissionInput,
  SUPER_ADMIN_PERMISSIONS,
} from './utils/adminPermissions';
import { writeAdminAuditLog } from './utils/auditLog';

function adminAccessState(data: FirebaseFirestore.DocumentData | undefined) {
  if (data == null) return null;
  return {
    role: data.role ?? null,
    adminRole: data.adminRole ?? null,
    adminPermissions: data.adminPermissions ?? null,
  };
}

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
  const targetRef = db.collection('users').doc(targetUid);
  const targetSnap = await targetRef.get();

  await auth.setCustomUserClaims(targetUid, {
    admin: true,
    role: 'admin',
    adminRole,
    adminPermissions:
      adminRole === 'super_admin' ? SUPER_ADMIN_PERMISSIONS : permissions,
  });

  await targetRef.update({
    role: 'admin',
    adminRole,
    adminPermissions: permissions,
    adminAccessUpdatedAt: FieldValue.serverTimestamp(),
    adminAccessUpdatedBy: caller.uid,
    updatedAt: FieldValue.serverTimestamp(),
  });

  await writeAdminAuditLog({
    action: 'set_admin_claim',
    actorId: caller.uid,
    targetUserId: targetUid,
    targetType: 'admin_user',
    before: adminAccessState(targetSnap.data()),
    after: { role: 'admin', adminRole, adminPermissions: permissions },
    data: { adminRole, permissions },
    context,
  });

  return { success: true };
});
