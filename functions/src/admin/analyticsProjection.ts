import { createHash } from 'crypto';
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { db, FieldValue } from '../utils/admin';
import {
  AnalyticsProjection,
  NumericTree,
  dateKey,
  nonEmptyString,
  paymentCreatedDeltas,
  paymentStatusDeltas,
  requestCreatedDeltas,
  requestStatusDeltas,
  sessionCreatedDeltas,
  sessionStatusDeltas,
  userCreatedDeltas,
  walletGroupDeltas,
} from './analyticsCore';

const SHARD_COUNT = 8;
const RECEIPT_RETENTION_DAYS = 730;
const TEACHER_ROLLING_WINDOWS = [30, 90, 365] as const;

function hash(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

function shardId(eventKey: string): string {
  const value = Number.parseInt(hash(eventKey).slice(0, 8), 16);
  return String(value % SHARD_COUNT).padStart(2, '0');
}

function teacherRollingIncrements(
  occurredAt: Date,
  deltas: NumericTree,
): Record<string, unknown> {
  const completed =
    typeof deltas.completedSessions === 'number'
      ? deltas.completedSessions
      : 0;
  const revenue =
    typeof deltas.sessionRevenueEgp === 'number'
      ? deltas.sessionRevenueEgp
      : 0;
  const eventDay = dateKey(occurredAt);
  const now = new Date();
  const result: Record<string, unknown> = {};

  for (const days of TEACHER_ROLLING_WINDOWS) {
    const cutoff = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
    if (eventDay <= dateKey(cutoff)) continue;
    result[`rolling${days}dCompletedSessions`] =
      FieldValue.increment(completed);
    result[`rolling${days}dRevenueEgp`] = FieldValue.increment(revenue);
  }
  return result;
}

function incrementTree(tree: NumericTree): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(tree)) {
    if (typeof value === 'number') {
      if (value !== 0) result[key] = FieldValue.increment(value);
    } else {
      const nested = incrementTree(value);
      if (Object.keys(nested).length > 0) result[key] = nested;
    }
  }
  return result;
}

function contextDate(timestamp: string): Date {
  const parsed = new Date(timestamp);
  return Number.isNaN(parsed.getTime()) ? new Date() : parsed;
}

function documentDate(
  data: Record<string, unknown>,
  fields: string[],
  fallback: Date,
): Date {
  for (const field of fields) {
    const value = data[field];
    if (value instanceof admin.firestore.Timestamp) return value.toDate();
    if (value instanceof Date) return value;
    if (typeof value === 'string') {
      const parsed = new Date(value);
      if (!Number.isNaN(parsed.getTime())) return parsed;
    }
  }
  return fallback;
}

export async function applyAnalyticsProjection(
  projection: AnalyticsProjection,
): Promise<boolean> {
  const receiptId = hash(projection.eventKey);
  const day = dateKey(projection.occurredAt);
  const receiptRef = db.collection('_adminAnalyticsEventReceipts').doc(receiptId);
  const shardRef = db
    .collection('_adminAnalyticsDailyShards')
    .doc(day)
    .collection('shards')
    .doc(shardId(projection.eventKey));
  const teacherId = nonEmptyString(projection.teacherId);
  const teacherDailyRef = teacherId
    ? db.collection('adminTeacherDaily').doc(`${day}_${teacherId}`)
    : null;
  const teacherSummaryRef = teacherId
    ? db.collection('adminTeacherAnalytics').doc(teacherId)
    : null;

  return db.runTransaction(async (tx) => {
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) return false;

    const expiresAt = new Date(
      projection.occurredAt.getTime() +
        RECEIPT_RETENTION_DAYS * 24 * 60 * 60 * 1000,
    );
    tx.create(receiptRef, {
      eventKey: projection.eventKey,
      dateKey: day,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });
    tx.set(
      shardRef,
      {
        dateKey: day,
        ...incrementTree(projection.deltas),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    if (
      teacherDailyRef != null &&
      teacherSummaryRef != null &&
      projection.teacherDeltas != null
    ) {
      const teacherIncrements = incrementTree(projection.teacherDeltas);
      const rollingIncrements = teacherRollingIncrements(
        projection.occurredAt,
        projection.teacherDeltas,
      );
      tx.set(
        teacherDailyRef,
        {
          dateKey: day,
          teacherId,
          teacherName: nonEmptyString(projection.teacherName, teacherId),
          ...teacherIncrements,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      tx.set(
        teacherSummaryRef,
        {
          teacherId,
          teacherName: nonEmptyString(projection.teacherName, teacherId),
          ...teacherIncrements,
          ...rollingIncrements,
          lastCompletedAt: admin.firestore.Timestamp.fromDate(
            projection.occurredAt,
          ),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    return true;
  });
}

export const onAnalyticsUserCreated = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() as Record<string, unknown>;
    const fallback = contextDate(context.timestamp);
    await applyAnalyticsProjection({
      eventKey: `users:${context.params.userId}:created`,
      occurredAt: documentDate(data, ['createdAt'], fallback),
      deltas: userCreatedDeltas(data),
    });
  });

export const onAnalyticsSessionRequestCreated = functions.firestore
  .document('sessionRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() as Record<string, unknown>;
    const fallback = contextDate(context.timestamp);
    await applyAnalyticsProjection({
      eventKey: `sessionRequests:${context.params.requestId}:created`,
      occurredAt: documentDate(data, ['createdAt'], fallback),
      deltas: requestCreatedDeltas(data),
    });
  });

export const onAnalyticsSessionRequestUpdated = functions.firestore
  .document('sessionRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as Record<string, unknown>;
    const after = change.after.data() as Record<string, unknown>;
    const deltas = requestStatusDeltas(before, after);
    if (deltas == null) return;
    const status = nonEmptyString(after.status, 'unknown');
    const fallback = contextDate(context.timestamp);
    await applyAnalyticsProjection({
      eventKey: `sessionRequests:${context.params.requestId}:status:${status}`,
      occurredAt: fallback,
      deltas,
    });
  });

export const onAnalyticsPaymentCreated = functions.firestore
  .document('payments/{paymentId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() as Record<string, unknown>;
    const fallback = contextDate(context.timestamp);
    await applyAnalyticsProjection({
      eventKey: `payments:${context.params.paymentId}:created`,
      occurredAt: documentDate(data, ['createdAt'], fallback),
      deltas: paymentCreatedDeltas(data),
    });

    const completed = paymentStatusDeltas({}, data);
    if (completed != null && data.status === 'completed') {
      await applyAnalyticsProjection({
        eventKey: `payments:${context.params.paymentId}:status:completed`,
        occurredAt: documentDate(data, ['paidAt', 'updatedAt'], fallback),
        deltas: completed,
      });
    }
  });

export const onAnalyticsPaymentUpdated = functions.firestore
  .document('payments/{paymentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as Record<string, unknown>;
    const after = change.after.data() as Record<string, unknown>;
    const deltas = paymentStatusDeltas(before, after);
    if (deltas == null) return;
    const status = nonEmptyString(after.status, 'unknown');
    const fallback = contextDate(context.timestamp);
    await applyAnalyticsProjection({
      eventKey: `payments:${context.params.paymentId}:status:${status}`,
      occurredAt: fallback,
      deltas,
    });
  });

export const onAnalyticsSessionCreated = functions.firestore
  .document('hafizSessions/{sessionId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() as Record<string, unknown>;
    const fallback = contextDate(context.timestamp);
    await applyAnalyticsProjection({
      eventKey: `hafizSessions:${context.params.sessionId}:created`,
      occurredAt: documentDate(data, ['createdAt'], fallback),
      deltas: sessionCreatedDeltas(data),
    });
  });

export const onAnalyticsSessionUpdated = functions.firestore
  .document('hafizSessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as Record<string, unknown>;
    const after = change.after.data() as Record<string, unknown>;
    const deltas = sessionStatusDeltas(before, after);
    if (deltas == null) return;
    const status = nonEmptyString(after.status, 'unknown');
    const fallback = contextDate(context.timestamp);
    const isCompletion = status === 'completed' && before.status !== 'completed';
    const eventParts: string[] = [];
    if (before.status !== after.status) eventParts.push(`status:${status}`);
    if (before.studentNoShow !== true && after.studentNoShow === true) {
      eventParts.push('studentNoShow:true');
    }
    if (before.teacherNoShow !== true && after.teacherNoShow === true) {
      eventParts.push('teacherNoShow:true');
    }
    const sessionPrice = Math.max(
      0,
      typeof after.sessionPrice === 'number' ? after.sessionPrice : 0,
    );
    await applyAnalyticsProjection({
      eventKey: `hafizSessions:${context.params.sessionId}:${eventParts.join('+')}`,
      occurredAt: fallback,
      deltas,
      teacherId: isCompletion ? nonEmptyString(after.mohaffezId) : undefined,
      teacherName: isCompletion ? nonEmptyString(after.mohaffezName) : undefined,
      teacherDeltas: isCompletion
        ? { completedSessions: 1, sessionRevenueEgp: sessionPrice }
        : undefined,
    });
  });

export const onAnalyticsWalletGroupCreated = functions.firestore
  .document('walletTransactionGroups/{groupId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() as Record<string, unknown>;
    const deltas = walletGroupDeltas(data);
    if (deltas == null) return;
    const fallback = contextDate(context.timestamp);
    await applyAnalyticsProjection({
      eventKey: `walletTransactionGroups:${context.params.groupId}:created`,
      occurredAt: documentDate(data, ['createdAt'], fallback),
      deltas,
    });
  });

export const onAnalyticsFailedOperationCreated = functions.firestore
  .document('failedOperations/{operationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() as Record<string, unknown>;
    const fallback = contextDate(context.timestamp);
    await applyAnalyticsProjection({
      eventKey: `failedOperations:${context.params.operationId}:created`,
      occurredAt: documentDate(data, ['timestamp', 'createdAt'], fallback),
      deltas: { operations: { failedOperationsCreated: 1 } },
    });
  });
