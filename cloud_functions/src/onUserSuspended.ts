import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

type TimeSlot = {
  enabled?: boolean;
  disabledBySuspension?: boolean;
  [key: string]: unknown;
};

const db = admin.firestore();

function asString(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

async function sendSuspendedNotification(uid: string, reason: string): Promise<void> {
  const userDoc = await db.collection('users').doc(uid).get();
  const userData = userDoc.data() ?? {};
  const fcmToken = asString(userData.fcmToken);

  if (!fcmToken) return;

  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: 'تم تقييد حسابك',
      body: reason || 'تم تقييد حسابك من قبل الإدارة',
    },
    data: {
      type: 'account_suspended',
      uid,
    },
  });
}

async function cancelPendingSessionRequests(uid: string): Promise<void> {
  const [asStudent, asMohaffez] = await Promise.all([
    db
        .collection('sessionRequests')
        .where('status', '==', 'pending')
        .where('studentId', '==', uid)
        .get(),
    db
        .collection('sessionRequests')
        .where('status', '==', 'pending')
        .where('mohaffezId', '==', uid)
        .get(),
  ]);

  const docs = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  for (const doc of asStudent.docs) docs.set(doc.id, doc);
  for (const doc of asMohaffez.docs) docs.set(doc.id, doc);

  const allDocs = [...docs.values()];
  for (let i = 0; i < allDocs.length; i += 400) {
    const batch = db.batch();
    const chunk = allDocs.slice(i, i + 400);
    for (const doc of chunk) {
      batch.update(doc.ref, {
        status: 'cancelled',
        cancelledBy: 'system',
        cancellationReason: 'account_suspended',
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

async function releaseSlotLocks(uid: string): Promise<void> {
  const locks = await db.collection('slotLocks').where('lockedBy', '==', uid).get();
  for (let i = 0; i < locks.docs.length; i += 400) {
    const batch = db.batch();
    const chunk = locks.docs.slice(i, i + 400);
    for (const doc of chunk) batch.delete(doc.ref);
    await batch.commit();
  }
}

async function disableMohaffezAvailability(uid: string): Promise<void> {
  const userDoc = await db.collection('users').doc(uid).get();
  const role = asString(userDoc.data()?.role);
  if (role !== 'mohaffez') return;

  const availabilityDocs = await db.collection('users').doc(uid).collection('availability').get();
  for (let i = 0; i < availabilityDocs.docs.length; i += 400) {
    const batch = db.batch();
    const chunk = availabilityDocs.docs.slice(i, i + 400);

    for (const doc of chunk) {
      const data = doc.data();
      const rawSlots = Array.isArray(data.timeSlots) ? data.timeSlots : [];
      const updatedSlots: TimeSlot[] = rawSlots.map((slot) => {
        const asMap = (slot && typeof slot === 'object' ? slot : {}) as TimeSlot;
        return {
          ...asMap,
          enabled: false,
          disabledBySuspension: true,
        };
      });

      batch.update(doc.ref, {
        timeSlots: updatedSlots,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}

export const onUserSuspended = functions.firestore
    .document('userSuspensions/{uid}')
    .onCreate(async (snap, context) => {
      const uid = asString(context.params.uid);
      const data = snap.data() ?? {};
      const reason = asString(data.reason);
      const suspendedBy = asString(data.suspendedBy);

      await sendSuspendedNotification(uid, reason);
      await cancelPendingSessionRequests(uid);
      await releaseSlotLocks(uid);
      await disableMohaffezAvailability(uid);

      // WHY: Record immutable admin-side trace for security-sensitive actions.
      await db.collection('adminAuditLog').add({
        action: 'user_suspended',
        targetUid: uid,
        reason,
        suspendedBy,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
