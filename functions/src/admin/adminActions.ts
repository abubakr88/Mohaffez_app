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
import { writeAdminAuditLog } from '../utils/auditLog';

type TargetRole = 'all' | 'student' | 'parent' | 'mohaffez';

function userAuditState(data: FirebaseFirestore.DocumentData | undefined) {
  if (data == null) return null;
  return {
    role: data.role ?? null,
    status: data.status ?? null,
    adminRole: data.adminRole ?? null,
    adminPermissions: data.adminPermissions ?? null,
    isDeleted: data.isDeleted ?? false,
    deletedAt: data.deletedAt ?? null,
    disabledAt: data.disabledAt ?? null,
  };
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
  if (newRole !== 'student' && newRole !== 'mohaffez') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'تغيير الدور من هنا متاح فقط بين طالب ومحفظ',
    );
  }

  await auth.getUser(userId);
  const userRef = db.collection('users').doc(userId);
  const beforeSnap = await userRef.get();
  if (!beforeSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'المستخدم غير موجود');
  }

  await userRef.update({
    role: newRole,
    roleUpdatedAt: FieldValue.serverTimestamp(),
    roleUpdatedBy: performedBy,
  });

  await writeAdminAuditLog({
    action: 'setUserRole',
    actorId: performedBy,
    targetUserId: userId,
    targetType: 'user',
    before: userAuditState(beforeSnap.data()),
    after: { ...(userAuditState(beforeSnap.data()) ?? {}), role: newRole },
    data: { newRole },
    context,
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

  await writeAdminAuditLog({
    action: 'updateAdminAccess',
    actorId: caller.uid,
    targetUserId: userId,
    targetType: 'admin_user',
    before: userAuditState(userSnap.data()),
    after: {
      ...(userAuditState(userSnap.data()) ?? {}),
      adminRole,
      adminPermissions: permissions,
    },
    data: { adminRole, permissions },
    context,
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
  const beforeSnap = await db.collection('users').doc(userId).get();
  if (!beforeSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'المستخدم غير موجود');
  }
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

  await writeAdminAuditLog({
    action: 'suspendUser',
    actorId: performedBy,
    targetUserId: userId,
    targetType: 'user',
    reason,
    before: userAuditState(beforeSnap.data()),
    after: { ...(userAuditState(beforeSnap.data()) ?? {}), status: 'suspended' },
    data: { reason, expiresAt: expiresAtRaw ?? null },
    context,
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
  const beforeSnap = await db.collection('users').doc(userId).get();
  if (!beforeSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'المستخدم غير موجود');
  }

  const batch = db.batch();
  batch.update(db.collection('users').doc(userId), {
    status: 'active',
    updatedAt: FieldValue.serverTimestamp(),
  });
  // WHY: Deleting suspension doc fully lifts lockout; guards/rules key off document existence.
  batch.delete(db.collection('userSuspensions').doc(userId));
  await batch.commit();

  await writeAdminAuditLog({
    action: 'unsuspendUser',
    actorId: performedBy,
    targetUserId: userId,
    targetType: 'user',
    before: userAuditState(beforeSnap.data()),
    after: { ...(userAuditState(beforeSnap.data()) ?? {}), status: 'active' },
    context,
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
  const caller = await requireAdminAccess(context, 'deleteUsers');
  const performedBy = caller.uid;
  const userId = (data?.userId as string | undefined)?.trim();
  const reason = (data?.reason as string | undefined)?.trim();

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'معرف المستخدم مطلوب');
  }
  if (!reason || reason.length < 3) {
    throw new functions.https.HttpsError('invalid-argument', 'سبب الحذف مطلوب');
  }
  if (userId === performedBy) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'لا يمكن حذف حسابك الحالي من لوحة التحكم',
    );
  }

  const userRef = db.collection('users').doc(userId);
  const beforeSnap = await userRef.get();
  if (!beforeSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'المستخدم غير موجود');
  }
  const before = beforeSnap.data();
  if (before?.role === 'admin' && caller.role !== 'super_admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'حذف حساب admin متاح للسوبر أدمن فقط',
    );
  }

  if (before?.isDeleted === true || before?.status === 'deleted') {
    return { success: true, softDeleted: true, alreadyDeleted: true };
  }

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

  await auth.updateUser(userId, { disabled: true });
  await auth.revokeRefreshTokens(userId);

  const batch = db.batch();
  for (const doc of [...studentLive.docs, ...mohaffezLive.docs]) {
    batch.update(doc.ref, {
      status: 'cancelled',
      cancelledBy: performedBy,
      cancellationReason: `account_soft_deleted: ${reason}`,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  batch.set(userRef, {
    status: 'deleted',
    isDeleted: true,
    deletedAt: FieldValue.serverTimestamp(),
    deletedBy: performedBy,
    deletionReason: reason,
    disabledAt: FieldValue.serverTimestamp(),
    disabledBy: performedBy,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  await batch.commit();

  await writeAdminAuditLog({
    action: 'deleteUserAccount',
    actorId: performedBy,
    targetUserId: userId,
    targetType: 'user',
    reason,
    before: userAuditState(before),
    after: { ...(userAuditState(before) ?? {}), status: 'deleted', isDeleted: true },
    data: {
      softDeleted: true,
      authDisabled: true,
      cancelledLiveRequests: studentLive.size + mohaffezLive.size,
    },
    context,
  });

  functions.logger.info('Admin soft-deleted user account', { performedBy, userId });
  return { success: true, softDeleted: true };
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

  await writeAdminAuditLog({
    action: 'deleteMyAccount',
    actorId: uid,
    targetUserId: uid,
    targetType: 'user',
    reason: 'user_self_delete',
    context,
  });

  functions.logger.info('User self-deleted account', { uid });
  return { success: true };
});

/**
 * input: { title: string, body: string, targetRole: 'all'|'student'|'parent'|'mohaffez' }
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

  await writeAdminAuditLog({
    action: 'sendBroadcastNotification',
    actorId: performedBy,
    targetType: 'broadcast',
    data: { title, targetRole, recipientCount: successCount },
    context,
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

  await writeAdminAuditLog({
    action: 'triggerCleanupJobManually',
    actorId: performedBy,
    targetType: 'maintenance',
    data: { released },
    context,
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

  const credRef = db.collection('users').doc(userId).collection('credentials').doc(credentialId);
  const credSnap = await credRef.get();
  if (!credSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'الشهادة غير موجودة');
  }

  await credRef.update({
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

  await writeAdminAuditLog({
    action: 'approveCredential',
    actorId: performedBy,
    targetUserId: userId,
    targetId: credentialId,
    targetType: 'credential',
    before: {
      status: credSnap.data()?.status ?? null,
      rejectionReason: credSnap.data()?.rejectionReason ?? null,
    },
    after: { status: 'approved', rejectionReason: null },
    data: { credentialId },
    context,
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

  const credRef = db.collection('users').doc(userId).collection('credentials').doc(credentialId);
  const credSnap = await credRef.get();
  if (!credSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'الشهادة غير موجودة');
  }

  await credRef.update({
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

  await writeAdminAuditLog({
    action: 'rejectCredential',
    actorId: performedBy,
    targetUserId: userId,
    targetId: credentialId,
    targetType: 'credential',
    reason,
    before: {
      status: credSnap.data()?.status ?? null,
      rejectionReason: credSnap.data()?.rejectionReason ?? null,
    },
    after: { status: 'rejected', rejectionReason: reason },
    data: { credentialId, reason },
    context,
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

  await writeAdminAuditLog({
    action: 'approveTeacher',
    actorId: performedBy,
    targetUserId: userId,
    targetType: 'teacher_review',
    before: userAuditState(snap.data()),
    after: { ...(userAuditState(snap.data()) ?? {}), status: 'active' },
    context,
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

  await writeAdminAuditLog({
    action: 'rejectTeacher',
    actorId: performedBy,
    targetUserId: userId,
    targetType: 'teacher_review',
    reason,
    before: userAuditState(snap.data()),
    after: { ...(userAuditState(snap.data()) ?? {}), status: 'rejected' },
    data: { reason },
    context,
  });

  functions.logger.info('Admin rejected teacher', { performedBy, userId, reason });
  return { success: true };
});

/**
 * input: { targetRole: 'all' | 'student' | 'parent' | 'mohaffez' }
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
