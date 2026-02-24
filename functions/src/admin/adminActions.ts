import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { auth, db, FieldValue, messaging } from '../utils/admin';
import { processWeeklyCommissionsNow } from '../payments/commissions';
import { releaseExpiredSlotLocksNow } from '../cleanup/releaseExpiredSlotLocks';

type TargetRole = 'all' | 'student' | 'mohaffez';

async function isAdminCaller(context: functions.https.CallableContext): Promise<boolean> {
  if (!context.auth?.uid) return false;
  if ((context.auth.token as { admin?: boolean }).admin === true) return true;
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  return userDoc.exists && userDoc.data()?.role === 'admin';
}

async function ensureAdmin(context: functions.https.CallableContext): Promise<string> {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }
  const ok = await isAdminCaller(context);
  if (!ok) {
    throw new functions.https.HttpsError('permission-denied', 'غير مصرح');
  }
  return context.auth.uid;
}

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
  const performedBy = await ensureAdmin(context);
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
 * input: { userId: string, reason: string, expiresAt?: string | null }
 * output: { success: true }
 */
export const suspendUser = functions.https.onCall(async (data, context) => {
  const performedBy = await ensureAdmin(context);
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
export const deleteUserAccount = functions.https.onCall(async (data, context) => {
  const performedBy = await ensureAdmin(context);
  const userId = (data?.userId as string | undefined)?.trim();

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'معرف المستخدم مطلوب');
  }

  await auth.getUser(userId);

  await auth.deleteUser(userId);
  await db.collection('users').doc(userId).delete();

  const studentPending = await db
    .collection('sessionRequests')
    .where('studentId', '==', userId)
    .where('status', '==', 'pending')
    .get();

  const mohaffezPending = await db
    .collection('sessionRequests')
    .where('mohaffezId', '==', userId)
    .where('status', '==', 'pending')
    .get();

  const batch = db.batch();
  for (const doc of [...studentPending.docs, ...mohaffezPending.docs]) {
    batch.update(doc.ref, {
      status: 'cancelled',
      cancelledBy: performedBy,
      cancellationReason: 'admin_delete_user',
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  await writeAuditLog({
    action: 'deleteUserAccount',
    performedBy,
    targetUserId: userId,
  });

  functions.logger.info('Admin deleted user account', { performedBy, userId });
  return { success: true };
});

/**
 * input: { title: string, body: string, targetRole: 'all'|'student'|'mohaffez' }
 * output: { recipientCount: number }
 */
export const sendBroadcastNotification = functions.https.onCall(async (data, context) => {
  const performedBy = await ensureAdmin(context);
  const title = (data?.title as string | undefined)?.trim();
  const body = (data?.body as string | undefined)?.trim();
  const targetRole = ((data?.targetRole as TargetRole | undefined) ?? 'all');

  if (!title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'عنوان ونص الإشعار مطلوبان');
  }

  let query: FirebaseFirestore.Query = db.collection('users');
  if (targetRole !== 'all') {
    query = query.where('role', '==', targetRole);
  }

  const usersSnap = await query.get();
  const tokens: string[] = [];
  for (const doc of usersSnap.docs) {
    const token = doc.data().fcmToken as string | undefined;
    if (token != null && token.length > 0) tokens.push(token);
  }

  const chunkSize = 500;
  for (let i = 0; i < tokens.length; i += chunkSize) {
    const chunk = tokens.slice(i, i + chunkSize);
    await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title, body },
      data: { type: 'broadcast', targetRole },
    });
  }

  await db.collection('broadcastHistory').add({
    title,
    body,
    targetRole,
    sentAt: FieldValue.serverTimestamp(),
    sentBy: performedBy,
    recipientCount: tokens.length,
  });

  await writeAuditLog({
    action: 'sendBroadcastNotification',
    performedBy,
    data: { title, targetRole, recipientCount: tokens.length },
  });

  functions.logger.info('Admin sent broadcast notification', {
    performedBy,
    targetRole,
    recipientCount: tokens.length,
  });

  return { recipientCount: tokens.length };
});

/**
 * input: {}
 * output: { processed: number }
 */
export const triggerCommissionJobManually = functions.https.onCall(async (_, context) => {
  const performedBy = await ensureAdmin(context);
  const processed = await processWeeklyCommissionsNow();

  await writeAuditLog({
    action: 'triggerCommissionJobManually',
    performedBy,
    data: { processed },
  });

  functions.logger.info('Admin triggered commissions job', { performedBy, processed });
  return { processed };
});

/**
 * input: {}
 * output: { released: number }
 */
export const triggerCleanupJobManually = functions.https.onCall(async (_, context) => {
  const performedBy = await ensureAdmin(context);
  const released = await releaseExpiredSlotLocksNow();

  await writeAuditLog({
    action: 'triggerCleanupJobManually',
    performedBy,
    data: { released },
  });

  functions.logger.info('Admin triggered cleanup job', { performedBy, released });
  return { released };
});
