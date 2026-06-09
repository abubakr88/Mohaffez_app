import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
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

  const targetUidRaw = (data?.targetUid as string | undefined)?.trim();
  const targetEmail = (data?.targetEmail as string | undefined)
    ?.trim()
    .toLowerCase();
  if (!targetUidRaw && !targetEmail) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'targetUid or targetEmail is required',
    );
  }

  let targetUser: admin.auth.UserRecord;
  try {
    targetUser = targetUidRaw
      ? await auth.getUser(targetUidRaw)
      : await auth.getUserByEmail(targetEmail!);
  } catch {
    throw new functions.https.HttpsError(
      'not-found',
      'Target auth user was not found',
    );
  }
  const targetUid = targetUser.uid;

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
  const targetData = targetSnap.data();

  await auth.setCustomUserClaims(targetUid, {
    admin: true,
    role: 'admin',
    adminRole,
    adminPermissions:
      adminRole === 'super_admin' ? SUPER_ADMIN_PERMISSIONS : permissions,
  });

  const profilePatch: FirebaseFirestore.DocumentData = {
    role: 'admin',
    adminRole,
    adminPermissions: permissions,
    adminAccessUpdatedAt: FieldValue.serverTimestamp(),
    adminAccessUpdatedBy: caller.uid,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (!targetSnap.exists || targetData?.email == null) {
    profilePatch.email = targetUser.email ?? targetEmail ?? null;
  }
  if (!targetSnap.exists || targetData?.name == null) {
    profilePatch.name =
      targetUser.displayName ?? targetUser.email ?? targetEmail ?? 'Admin';
  }
  if (!targetSnap.exists || targetData?.status == null) {
    profilePatch.status = 'active';
  }
  if (!targetSnap.exists || targetData?.createdAt == null) {
    profilePatch.createdAt = FieldValue.serverTimestamp();
  }

  await targetRef.set(profilePatch, { merge: true });

  await writeAdminAuditLog({
    action: 'set_admin_claim',
    actorId: caller.uid,
    targetUserId: targetUid,
    targetType: 'admin_user',
    before: adminAccessState(targetSnap.data()),
    after: { role: 'admin', adminRole, adminPermissions: permissions },
    data: {
      adminRole,
      permissions,
      targetEmail: targetUser.email ?? targetEmail ?? null,
    },
    context,
  });

  return { success: true };
});
