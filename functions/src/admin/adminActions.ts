import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { auth, db, FieldValue, messaging } from '../utils/admin';
import { releaseExpiredSlotLocksNow } from '../cleanup/releaseExpiredSlotLocks';
import {
  AdminRole,
  requireAdminAccess,
  requireSuperAdminAccess,
  sanitizePermissionInput,
  SUPER_ADMIN_PERMISSIONS,
} from '../utils/adminPermissions';

type TargetRole = 'all' | 'student' | 'mohaffez';

async function writeAuditLog(params: {
  action: string;
  performedBy: string;
  targetUserId?: string;
  data?: Record<string, unknown>;
}): Promise<void> {
  await db.collection('adminAuditLog').add({
    action: params.action,
    performedBy: params.performedBy,
    targetUserId: params.targetUserId ?? null,
    data: params.data ?? null,
    timestamp: FieldValue.serverTimestamp(),
  });
}

/**
 * input: { userId: string, newRole: string }
 * output: { success: true }
 */
export const setUserRole = functions.https.onCall(async (data, context) => {
  const performedBy = (await requireAdminAccess(context, 'manageUserRoles')).uid;
  const userId = (data?.userId as string | undefined)?.trim();
  const newRole = (data?.newRole as string | undefined)?.trim();

  if (!userId || !newRole) {
    throw new functions.https.HttpsError('invalid-argument', 'يرجى إدخال جميع الحقول المطلوبة');
  }

  await auth.getUser(userId);

  await db.collection('users').doc(userId).update({
    role: newRole,
    roleUpdatedAt: FieldValue.serverTimestamp(),
    roleUpdatedBy: performedBy,
  });

  await writeAuditLog({
    action: 'setUserRole',
    performedBy,
    targetUserId: userId,
    data: { newRole },
  });

  functions.logger.info('Admin set user role', { performedBy, userId, newRole });
  return { success: true };
});

/**
 * input: {
 *   userId: string,
 *   adminRole: 'super_admin' | 'admin',
 *   permissions?: Record<string, boolean>
 * }
 * output: { success: true }
 */
export const updateAdminAccess = functions.https.onCall(async (data, context) => {
  const caller = await requireSuperAdminAccess(context);
  const userId = (data?.userId as string | undefined)?.trim();
  const requestedRole = (data?.adminRole as string | undefined)?.trim();

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'معرف المستخدم مطلوب');
  }
  if (requestedRole !== 'super_admin' && requestedRole !== 'admin') {
    throw new functions.https.HttpsError('invalid-argument', 'نوع صلاحية الأدمن غير صحيح');
  }
  if (userId === caller.uid && requestedRole !== 'super_admin') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'لا يمكن تقليل صلاحيات حسابك الحالي',
    );
  }

  await auth.getUser(userId);
  const userRef = db.collection('users').doc(userId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'المستخدم غير موجود');
  }
  if (userSnap.data()?.role !== 'admin') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'إدارة صلاحيات الأدمن متاحة لحسابات admin فقط',
    );
  }

  const adminRole = requestedRole as AdminRole;
  const permissions =
    adminRole === 'super_admin'
      ? {}
      : sanitizePermissionInput(data?.permissions);

  await userRef.update({
    adminRole,
    adminPermissions: permissions,
    adminAccessUpdatedAt: FieldValue.serverTimestamp(),
    adminAccessUpdatedBy: caller.uid,
    updatedAt: FieldValue.serverTimestamp(),
  });

  await auth.setCustomUserClaims(userId, {
    admin: true,
    role: 'admin',
    adminRole,
    adminPermissions:
      adminRole === 'super_admin' ? SUPER_ADMIN_PERMISSIONS : permissions,
  });

  await writeAuditLog({
    action: 'updateAdminAccess',
    performedBy: caller.uid,
    targetUserId: userId,
    data: { adminRole, permissions },
  });

  functions.logger.info('Admin access updated', {
    performedBy: caller.uid,
    userId,
    adminRole,
  });
  return { success: true };
});

/**
 * input: { userId: string, reason: string, expiresAt?: string | null }
 * output: { success: true }
 */
export const suspendUser = functions.https.onCall(async (data, context) => {
  const performedBy = (await requireAdminAccess(context, 'manageUsers')).uid;
  const userId = (data?.userId as string | undefined)?.trim();
  const reason = (data?.reason as string | undefined)?.trim() ?? '';
  const expiresAtRaw = data?.expiresAt as string | null | undefined;

  if (!userId || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'سبب الإيقاف مطلوب');
  }

  const userRecord = await auth.getUser(userId);
  const expiresAt = expiresAtRaw ? admin.firestore.Timestamp.fromDate(new Date(expiresAtRaw)) : null;

  const batch = db.batch();
  batch.update(db.collection('users').doc(userId), {
    status: 'suspended',
    updatedAt: FieldValue.serverTimestamp(),
  });
  batch.set(db.collection('userSuspensions').doc(userId), {
    userId,
    suspendedBy: performedBy,
    reason,
    suspendedAt: FieldValue.serverTimestamp(),
    expiresAt,
    isActive: true,
  }, { merge: true });
  await batch.commit();

  const configDoc = await db.collection('systemConfig').doc('global').get();
  const fcmEnabled = configDoc.data()?.fcmEnabled != false;
  const targetDoc = await db.collection('users').doc(userId).get();
  const token = targetDoc.data()?.fcmToken as string | undefined;

  if (fcmEnabled && token != null && token.length > 0) {
    await messaging.send({
      token,
      notification: {
        title: 'تم إيقاف الحساب',
        body: reason,
      },
      data: {
        type: 'account_suspended',
        uid: userRecord.uid,
      },
    });
  }

  await writeAuditLog({
    action: 'suspendUser',
    performedBy,
    targetUserId: userId,
    data: { reason, expiresAt: expiresAtRaw ?? null },
  });

  functions.logger.info('Admin suspended user', { performedBy, userId });
  return { success: true };
});

/**
 * input: { userId: string }
 * output: { success: true }
 */
export const unsuspendUser = functions.https.onCall(async (data, context) => {
  const performedBy = (await requireAdminAccess(context, 'manageUsers')).uid;
  const userId = (data?.userId as string | undefined)?.trim();

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'معرف المستخدم مطلوب');
  }

  await auth.getUser(userId);

  const batch = db.batch();
  batch.update(db.collection('users').doc(userId), {
    status: 'active',
    updatedAt: FieldValue.serverTimestamp(),
  });
  // WHY: Deleting suspension doc fully lifts lockout; guards/rules key off document existence.
  batch.delete(db.collection('userSuspensions').doc(userId));
  await batch.commit();

  await writeAuditLog({
    action: 'unsuspendUser',
    performedBy,
    targetUserId: userId,
  });

  functions.logger.info('Admin unsuspended user', { performedBy, userId });
  return { success: true };
});

/**
 * input: { userId: string }
 * output: { success: true }
 */
/**
 * Shared deletion routine used by both the admin-initiated delete and the
 * user self-service delete. Cancels all live session requests the user is part
 * of (as student or teacher), deletes their profile doc, then deletes their
 * Auth account. Historical/financial records (payments, completed sessions,
 * wallet ledger) are intentionally retained for legal/accounting purposes.
 *
 * @param userId       the account being deleted
 * @param performedBy  who triggered it (admin uid, or the user's own uid)
 * @param reason       cancellation reason stamped on live requests
 */
async function performAccountDeletion(
  userId: string,
  performedBy: string,
  reason: string,
): Promise<void> {
  await auth.getUser(userId);

  // FIX-DELETE-1: Cancel all live requests, not just pending.
  const LIVE_STATUSES_FOR_DELETE = [
    'pending',
    'awaitingpayment',
    'awaitingdirectpaymentconfirmation',
    'accepted',
  ];

  const [studentLive, mohaffezLive] = await Promise.all([
    db
      .collection('sessionRequests')
      .where('studentId', '==', userId)
      .where('status', 'in', LIVE_STATUSES_FOR_DELETE)
      .get(),
    db
      .collection('sessionRequests')
      .where('mohaffezId', '==', userId)
      .where('status', 'in', LIVE_STATUSES_FOR_DELETE)
      .get(),
  ]);

  const batch = db.batch();
  for (const doc of [...studentLive.docs, ...mohaffezLive.docs]) {
    batch.update(doc.ref, {
      status: 'cancelled',
      cancelledBy: performedBy,
      cancellationReason: reason,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  batch.delete(db.collection('users').doc(userId));

  // FIXED: BUG-2 - Delete Auth FIRST, then Firestore
  try {
    await auth.deleteUser(userId);
  } catch (authErr) {
    functions.logger.error('performAccountDeletion: Auth delete failed', { userId, authErr });
    throw new functions.https.HttpsError('internal', 'Failed to delete auth account');
  }
  await batch.commit();
}

export const deleteUserAccount = functions.https.onCall(async (data, context) => {
  const performedBy = (await requireAdminAccess(context, 'deleteUsers')).uid;
  const userId = (data?.userId as string | undefined)?.trim();

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'معرف المستخدم مطلوب');
  }

  await performAccountDeletion(userId, performedBy, 'admin_delete_user');

  await writeAuditLog({
    action: 'deleteUserAccount',
    performedBy,
    targetUserId: userId,
  });

  functions.logger.info('Admin deleted user account', { performedBy, userId });
  return { success: true };
});

/**
 * Self-service account deletion (Google Play Data Safety requirement).
 * Any authenticated user can permanently delete their OWN account. Takes no
 * userId argument — the target is always the caller, so one user can never
 * delete another. Deletion is processed by the Admin SDK, so the client does
 * not need to re-authenticate first.
 *
 * input: {} (none) · output: { success: true }
 */
export const deleteMyAccount = functions.https.onCall(async (_data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }

  await performAccountDeletion(uid, uid, 'user_self_delete');

  await writeAuditLog({
    action: 'deleteMyAccount',
    performedBy: uid,
    targetUserId: uid,
  });

  functions.logger.info('User self-deleted account', { uid });
  return { success: true };
});

/**
 * input: { title: string, body: string, targetRole: 'all'|'student'|'mohaffez' }
 * output: { recipientCount: number }
 */
export const sendBroadcastNotification = functions.https.onCall(async (data, context) => {
  const performedBy = (await requireAdminAccess(context, 'sendBroadcasts')).uid;
  const title = data?.title as string | undefined;
  const body = data?.body as string | undefined;
  const targetRole = (data?.targetRole as TargetRole | undefined) ?? 'all';

  if (!title || !body) throw new functions.https.HttpsError('invalid-argument', '');

  let query: FirebaseFirestore.Query = db.collection('users');
  if (targetRole !== 'all') query = query.where('role', '==', targetRole);

  const usersSnap = await query.get();
  const tokens: string[] = [];
  const userIds: string[] = []; // ✅ collect UIDs alongside tokens

  for (const doc of usersSnap.docs) {
    const token = doc.data().fcmToken as string | undefined;
    if (token != null && token.length > 0) {
      tokens.push(token);
      userIds.push(doc.id); // ✅ track which user owns each token
    }
  }

  const chunkSize = 500;
  let successCount = 0;
  // FIX: Respect global FCM toggle for broadcast push sending while keeping in-app docs active.
  const configDoc = await db.collection('systemConfig').doc('global').get();
  const fcmEnabled = configDoc.data()?.fcmEnabled !== false;

  for (let i = 0; i < tokens.length; i += chunkSize) {
    const chunk = tokens.slice(i, i + chunkSize);
    const userChunk = userIds.slice(i, i + chunkSize); // ✅ same slice

    let batchResponse: admin.messaging.BatchResponse | null = null;
    if (fcmEnabled && chunk.length > 0) {
      batchResponse = await messaging.sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        data: { type: 'broadcast', targetRole },
      });
      successCount += batchResponse.successCount;
    }

    // FIX: Always write an in-app notification doc for every targeted user, even if FCM fails/disabled.
    const writeBatch = db.batch();
    for (let j = 0; j < userChunk.length; j++) {
      const notifRef = db.collection('notifications').doc();
      writeBatch.set(notifRef, {
        userId: userChunk[j],
        recipientId: userChunk[j],
        senderId: performedBy,
        title,
        body,
        type: 'broadcast',
        isRead: false,
        data: { type: 'broadcast', targetRole },
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await writeBatch.commit();
  }

  await db.collection('broadcastHistory').add({
    title,
    body,
    targetRole,
    sentAt: FieldValue.serverTimestamp(),
    sentBy: performedBy,
    recipientCount: successCount,
    totalTokens: tokens.length,
  });

  await writeAuditLog({
    action: 'sendBroadcastNotification',
    performedBy,
    data: { title, targetRole, recipientCount: successCount },
  });

  return { recipientCount: successCount };
});

/**
 * input: {}
 * output: { released: number }
 */
export const triggerCleanupJobManually = functions.https.onCall(async (_, context) => {
  const performedBy = (await requireAdminAccess(context, 'runMaintenance')).uid;
  const released = await releaseExpiredSlotLocksNow();

  await writeAuditLog({
    action: 'triggerCleanupJobManually',
    performedBy,
    data: { released },
  });

  functions.logger.info('Admin triggered cleanup job', { performedBy, released });
  return { released };
});

/**
 * input: { userId: string, credentialId: string }
 * output: { success: true }
 */
export const approveCredential = functions.https.onCall(async (data, context) => {
  const performedBy = (await requireAdminAccess(context, 'reviewTeachers')).uid;
  const userId = (data?.userId as string | undefined)?.trim();
  const credentialId = (data?.credentialId as string | undefined)?.trim();

  if (!userId || !credentialId) {
    throw new functions.https.HttpsError('invalid-argument', 'معرف المستخدم ومعرف الشهادة مطلوبان');
  }

  await db.collection('users').doc(userId).collection('credentials').doc(credentialId).update({
    status: 'approved',
    reviewedAt: FieldValue.serverTimestamp(),
    reviewedBy: performedBy,
  });

  const { createAndSendNotification } = await import('../utils/notificationHelpers');
  await createAndSendNotification({
    userId,
    title: 'تم اعتماد الشهادة',
    body: 'تم قبول شهادتك بنجاح ✅',
    type: 'credential_approved',
  });

  await writeAuditLog({
    action: 'approveCredential',
    performedBy,
    targetUserId: userId,
    data: { credentialId },
  });

  functions.logger.info('Admin approved credential', { performedBy, userId, credentialId });
  return { success: true };
});

/**
 * input: { userId: string, credentialId: string, reason: string }
 * output: { success: true }
 */
export const rejectCredential = functions.https.onCall(async (data, context) => {
  const performedBy = (await requireAdminAccess(context, 'reviewTeachers')).uid;
  const userId = (data?.userId as string | undefined)?.trim();
  const credentialId = (data?.credentialId as string | undefined)?.trim();
  const reason = (data?.reason as string | undefined)?.trim();

  if (!userId || !credentialId || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'معرف المستخدم ومعرف الشهادة وسبب الرفض مطلوبون');
  }

  await db.collection('users').doc(userId).collection('credentials').doc(credentialId).update({
    status: 'rejected',
    rejectionReason: reason,
    reviewedAt: FieldValue.serverTimestamp(),
    reviewedBy: performedBy,
  });

  const { createAndSendNotification } = await import('../utils/notificationHelpers');
  await createAndSendNotification({
    userId,
    title: 'تم رفض الشهادة',
    body: reason,
    type: 'credential_rejected',
  });

  await writeAuditLog({
    action: 'rejectCredential',
    performedBy,
    targetUserId: userId,
    data: { credentialId, reason },
  });

  functions.logger.info('Admin rejected credential', { performedBy, userId, credentialId, reason });
  return { success: true };
});

/**
 * Approve a teacher whose account is awaiting verification.
 * Flips users/{uid}.status 'pending_approval' → 'active' so the mobile RoleGuard
 * lets them into the teacher home on next launch.
 * input: { userId: string }
 * output: { success: true }
 */
export const approveTeacher = functions.https.onCall(async (data, context) => {
  const performedBy = (await requireAdminAccess(context, 'reviewTeachers')).uid;
  const userId = (data?.userId as string | undefined)?.trim();

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'معرف المستخدم مطلوب');
  }

  const userRef = db.collection('users').doc(userId);
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'المستخدم غير موجود');
  }
  if (snap.data()?.role !== 'mohaffez') {
    throw new functions.https.HttpsError('failed-precondition', 'هذا الحساب ليس محفظًا');
  }

  await userRef.update({
    status: 'active',
    rejectionReason: FieldValue.delete(),
    approvalReviewedAt: FieldValue.serverTimestamp(),
    approvalReviewedBy: performedBy,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const { createAndSendNotification } = await import('../utils/notificationHelpers');
  await createAndSendNotification({
    userId,
    title: 'تم اعتماد حسابك',
    body: 'تهانينا! تم قبول طلب التحقق ويمكنك الآن استقبال الطلاب ✅',
    type: 'teacher_approved',
  });

  await writeAuditLog({
    action: 'approveTeacher',
    performedBy,
    targetUserId: userId,
  });

  functions.logger.info('Admin approved teacher', { performedBy, userId });
  return { success: true };
});

/**
 * Reject a teacher's verification request.
 * Flips users/{uid}.status → 'rejected'; the mobile RoleGuard routes them to
 * /teacher-rejected with the stored reason.
 * input: { userId: string, reason: string }
 * output: { success: true }
 */
export const rejectTeacher = functions.https.onCall(async (data, context) => {
  const performedBy = (await requireAdminAccess(context, 'reviewTeachers')).uid;
  const userId = (data?.userId as string | undefined)?.trim();
  const reason = (data?.reason as string | undefined)?.trim();

  if (!userId || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'معرف المستخدم وسبب الرفض مطلوبان');
  }

  const userRef = db.collection('users').doc(userId);
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'المستخدم غير موجود');
  }

  await userRef.update({
    status: 'rejected',
    rejectionReason: reason,
    approvalReviewedAt: FieldValue.serverTimestamp(),
    approvalReviewedBy: performedBy,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const { createAndSendNotification } = await import('../utils/notificationHelpers');
  await createAndSendNotification({
    userId,
    title: 'تم رفض طلب التحقق',
    body: reason,
    type: 'teacher_rejected',
  });

  await writeAuditLog({
    action: 'rejectTeacher',
    performedBy,
    targetUserId: userId,
    data: { reason },
  });

  functions.logger.info('Admin rejected teacher', { performedBy, userId, reason });
  return { success: true };
});

/**
 * input: { targetRole: 'all' | 'student' | 'mohaffez' }
 * output: { count: number }
 */
export const getBroadcastAudienceCount = functions.https.onCall(async (data, context) => {
  await requireAdminAccess(context, 'sendBroadcasts');
  const targetRole = ((data?.targetRole as TargetRole | undefined) ?? 'all');

  let query: FirebaseFirestore.Query = db.collection('users');
  if (targetRole !== 'all') {
    query = query.where('role', '==', targetRole);
  }

  const usersSnap = await query.get();
  let count = 0;
  for (const doc of usersSnap.docs) {
    const token = doc.data().fcmToken as string | undefined;
    if (token != null && token.length > 0) count++;
  }

  functions.logger.info('Admin queried broadcast audience count', { targetRole, count });
  return { count };
});
