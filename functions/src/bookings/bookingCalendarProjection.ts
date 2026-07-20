import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { db, FieldValue } from '../utils/admin';

const LIVE_REQUEST_STATUSES = [
  'pending',
  'awaitingpayment',
  'awaitingdirectpaymentconfirmation',
  'accepted',
] as const;

type CalendarTarget = {
  mohaffezId: string;
  slotDate: admin.firestore.Timestamp;
};

const CONFIG_CACHE_TTL_MS = 60 * 1000;
let cachedFeatureEnabled = false;
let cachedFeatureCheckedAt = 0;

async function isVariablePlanDurationEnabled(): Promise<boolean> {
  const now = Date.now();
  if (now - cachedFeatureCheckedAt < CONFIG_CACHE_TTL_MS) {
    return cachedFeatureEnabled;
  }

  const config = await db.collection('systemConfig').doc('global').get();
  cachedFeatureEnabled =
    config.data()?.variablePlanSessionDurationEnabled === true;
  cachedFeatureCheckedAt = now;
  return cachedFeatureEnabled;
}

function timestampValue(value: unknown): admin.firestore.Timestamp | null {
  return value instanceof admin.firestore.Timestamp ? value : null;
}

function targetFromRequest(
  data: FirebaseFirestore.DocumentData | undefined,
): CalendarTarget | null {
  if (!data || typeof data.mohaffezId !== 'string') return null;
  const slotDate = timestampValue(data.slotDate);
  if (!slotDate) return null;
  return { mohaffezId: data.mohaffezId, slotDate };
}

function targetKey(target: CalendarTarget): string {
  return `${target.mohaffezId}:${target.slotDate.toMillis()}`;
}

function calendarDateId(slotDate: admin.firestore.Timestamp): string {
  return slotDate.toDate().toISOString().slice(0, 10);
}

async function rebuildBookingCalendarDay(target: CalendarTarget) {
  const requests = await db
    .collection('sessionRequests')
    .where('mohaffezId', '==', target.mohaffezId)
    .where('status', 'in', [...LIVE_REQUEST_STATUSES])
    .where('slotDate', '==', target.slotDate)
    .get();

  const uniqueIntervals = new Map<string, Record<string, unknown>>();
  for (const request of requests.docs) {
    const data = request.data();
    const slotStart = timestampValue(data.slotStart);
    const slotEnd = timestampValue(data.slotEnd);
    if (!slotStart || !slotEnd || slotEnd.toMillis() <= slotStart.toMillis()) {
      continue;
    }

    const breakMinutes =
      typeof data.breakMinutesAfter === 'number' &&
      Number.isFinite(data.breakMinutesAfter)
        ? Math.max(0, Math.round(data.breakMinutesAfter))
        : 0;
    const reservedUntil = admin.firestore.Timestamp.fromMillis(
      slotEnd.toMillis() + breakMinutes * 60 * 1000,
    );
    const key = `${slotStart.toMillis()}:${slotEnd.toMillis()}:${reservedUntil.toMillis()}`;
    uniqueIntervals.set(key, {
      slotStart,
      slotEnd,
      reservedUntil,
      sessionType:
        typeof data.sessionType === 'string' ? data.sessionType : 'online',
    });
  }

  const intervals = [...uniqueIntervals.values()].sort((a, b) => {
    const aStart = a.slotStart as admin.firestore.Timestamp;
    const bStart = b.slotStart as admin.firestore.Timestamp;
    return aStart.toMillis() - bStart.toMillis();
  });
  const calendarRef = db
    .collection('users')
    .doc(target.mohaffezId)
    .collection('bookingCalendar')
    .doc(calendarDateId(target.slotDate));

  if (intervals.length === 0) {
    await calendarRef.delete().catch((error: unknown) => {
      functions.logger.warn('booking calendar delete skipped', {
        mohaffezId: target.mohaffezId,
        slotDate: target.slotDate.toDate().toISOString(),
        error,
      });
    });
    return;
  }

  await calendarRef.set({
    dateUtc: target.slotDate,
    intervals,
    intervalCount: intervals.length,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Maintains a small, PII-free daily projection used only to hide occupied
 * choices in the booking UI. createSessionRequest remains the authoritative
 * overlap guard and never trusts this eventually-consistent projection.
 */
export const onSessionRequestBookingCalendarChanged = functions.firestore
  .document('sessionRequests/{requestId}')
  .onWrite(async (change) => {
    if (!(await isVariablePlanDurationEnabled())) return;

    const targets = new Map<string, CalendarTarget>();
    const before = targetFromRequest(
      change.before.exists ? change.before.data() : undefined,
    );
    const after = targetFromRequest(
      change.after.exists ? change.after.data() : undefined,
    );
    if (before) targets.set(targetKey(before), before);
    if (after) targets.set(targetKey(after), after);

    await Promise.all([...targets.values()].map(rebuildBookingCalendarDay));
  });
