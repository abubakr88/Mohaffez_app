import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db } from "../utils/admin";
import { isAcceptingNewBookings } from "../teacherBookingPolicy";
import {
  addLocalDays,
  clockFromMinutes,
  dateKey,
  isoWeekday,
  localDateTime,
  minutesFromClock,
  TEACHER_TIME_ZONE_ID,
  teacherLocalSnapshot,
  zonedParts,
} from "./bookingTimeZone";

const SESSION_TYPES = new Set(["online", "mosque", "home"]);
const DEFAULT_DURATION_MINUTES = 45;
const DEFAULT_BREAKS: Readonly<Record<string, number>> = {
  online: 10,
  mosque: 15,
  home: 30,
};

interface OccupiedInterval {
  start: Date;
  reservedUntil: Date;
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new functions.https.HttpsError("invalid-argument", `${field} is required`);
  }
  return value.trim();
}

function optionalString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function storedDuration(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  const duration = Math.trunc(value);
  return duration >= 5 && duration <= 240 ? duration : null;
}

function nonNegativeMinutes(value: unknown, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.max(0, Math.min(120, Math.trunc(value)));
}

function overlapsExclusion(start: number, end: number, raw: unknown): boolean {
  if (!Array.isArray(raw)) return false;
  return raw.some((item) => {
    if (!item || typeof item !== "object") return false;
    const range = item as Record<string, unknown>;
    const rangeStart = minutesFromClock(range.start);
    const rangeEnd = minutesFromClock(range.end);
    return rangeStart !== null && rangeEnd !== null &&
      start < rangeEnd && end > rangeStart;
  });
}

function timestampDate(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

async function authoritativeDuration(
  studentId: string,
  mohaffezId: string,
  sessionType: string,
  planId: string | null,
  subscriptionId: string | null,
  scheduleDuration: unknown,
): Promise<number> {
  if (subscriptionId) {
    const subscription = await db.collection("subscriptions").doc(subscriptionId).get();
    const value = subscription.data() ?? {};
    const expiryDate = timestampDate(value.expiryDate);
    const remainingSessions = Number(value.remainingSessions ?? 0);
    if (!subscription.exists || value.studentId !== studentId ||
        value.mohaffezId !== mohaffezId || value.status !== "active" ||
        (value.sessionType && value.sessionType !== sessionType) ||
        !Number.isFinite(remainingSessions) || remainingSessions <= 0 ||
        (expiryDate && expiryDate.getTime() < Date.now())) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "الاشتراك غير متاح لحجز هذا الموعد",
      );
    }
    const subscriptionDuration = storedDuration(value.sessionDurationMinutes);
    if (subscriptionDuration) return subscriptionDuration;
    const subscriptionPlanId = optionalString(value.planId);
    if (subscriptionPlanId) {
      const plan = await db.collection("users").doc(mohaffezId)
        .collection("pricingPlans").doc(subscriptionPlanId).get();
      const planDuration = storedDuration(plan.data()?.sessionDurationMinutes);
      if (planDuration) return planDuration;
    }
  }

  if (planId) {
    const plan = await db.collection("users").doc(mohaffezId)
      .collection("pricingPlans").doc(planId).get();
    const value = plan.data() ?? {};
    if (!plan.exists || value.isActive !== true ||
        (value.mode && value.mode !== sessionType)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "الخطة غير متاحة لنوع الجلسة المختار",
      );
    }
    const planDuration = storedDuration(value.sessionDurationMinutes);
    if (planDuration) return planDuration;
  }

  return storedDuration(scheduleDuration) ?? DEFAULT_DURATION_MINUTES;
}

async function occupiedIntervals(from: Date, to: Date, mohaffezId: string): Promise<OccupiedInterval[]> {
  const rangeStart = admin.firestore.Timestamp.fromDate(
    new Date(from.getTime() - 2 * 86_400_000),
  );
  const rangeEnd = admin.firestore.Timestamp.fromDate(
    new Date(to.getTime() + 2 * 86_400_000),
  );
  const snapshot = await db.collection("users").doc(mohaffezId)
    .collection("bookingCalendar")
    .where("dateUtc", ">=", rangeStart)
    .where("dateUtc", "<", rangeEnd)
    .get();
  const result: OccupiedInterval[] = [];
  for (const doc of snapshot.docs) {
    const intervals = doc.data().intervals;
    if (!Array.isArray(intervals)) continue;
    for (const raw of intervals) {
      if (!raw || typeof raw !== "object") continue;
      const interval = raw as Record<string, unknown>;
      const start = timestampDate(interval.slotStart);
      const reservedUntil = timestampDate(interval.reservedUntil) ??
        timestampDate(interval.slotEnd);
      if (start && reservedUntil) result.push({start, reservedUntil});
    }
  }
  return result;
}

function intervalOccupied(
  start: Date,
  end: Date,
  breakMinutes: number,
  occupied: OccupiedInterval[],
): boolean {
  const reservedUntil = new Date(end.getTime() + breakMinutes * 60_000);
  return occupied.some((item) =>
    start < item.reservedUntil && item.start < reservedUntil,
  );
}

export const listAvailableSlots = functions.https.onCall(async (data, context) => {
  const studentId = context.auth?.uid;
  if (!studentId) {
    throw new functions.https.HttpsError("unauthenticated", "Login required");
  }
  const mohaffezId = requiredString(data?.mohaffezId, "mohaffezId");
  const sessionType = requiredString(data?.sessionType, "sessionType");
  if (!SESSION_TYPES.has(sessionType)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid sessionType");
  }
  const planId = optionalString(data?.planId);
  const subscriptionId = optionalString(data?.subscriptionId);
  const teacherTimeZoneId = TEACHER_TIME_ZONE_ID;
  const now = new Date();
  const endOfWindow = new Date(now.getTime() + 7 * 86_400_000);

  const userRef = db.collection("users").doc(mohaffezId);
  const scheduleRef = userRef.collection("settings").doc("schedule");
  const [teacherSnap, scheduleSnap, availabilitySnap, occupied] = await Promise.all([
    userRef.get(),
    scheduleRef.get(),
    userRef.collection("availability").get(),
    occupiedIntervals(now, endOfWindow, mohaffezId),
  ]);
  const teacher = teacherSnap.data() ?? {};
  if (!teacherSnap.exists || teacher.role !== "mohaffez" || teacher.status !== "active") {
    throw new functions.https.HttpsError("not-found", "teacher-not-found");
  }
  if (!isAcceptingNewBookings(teacher)) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "المحفظ لا يستقبل حجوزات جديدة حالياً",
    );
  }
  const schedule = scheduleSnap.data() ?? {};

  const durationMinutes = await authoritativeDuration(
    studentId,
    mohaffezId,
    sessionType,
    planId,
    subscriptionId,
    schedule.sessionDuration,
  );
  const teacherToday = dateKey(zonedParts(now, teacherTimeZoneId));
  const availabilityByWeekday = new Map<number, FirebaseFirestore.QueryDocumentSnapshot>();
  for (const doc of availabilitySnap.docs) {
    const day = doc.data().dayOfWeek;
    if (typeof day === "number" && day >= 1 && day <= 7) {
      availabilityByWeekday.set(day, doc);
    }
  }

  const slots: Record<string, unknown>[] = [];
  for (let dayOffset = -1; dayOffset <= 8; dayOffset += 1) {
    const teacherLocalDate = addLocalDays(teacherToday, dayOffset);
    const availabilityDoc = availabilityByWeekday.get(isoWeekday(teacherLocalDate));
    if (!availabilityDoc) continue;
    const day = availabilityDoc.data();
    const availableTypes = Array.isArray(day.sessionTypes)
      ? day.sessionTypes.filter((value) => typeof value === "string")
      : [];
    const schemaVersion = typeof day.scheduleSchemaVersion === "number"
      ? Math.trunc(day.scheduleSchemaVersion)
      : 1;
    const candidates: Array<{start: string; end: string}> = [];

    if (schemaVersion >= 2 && day.scheduleMode === "availabilityWindows") {
      if (!availableTypes.includes(sessionType)) continue;
      const windowStart = minutesFromClock(day.startTime);
      const windowEnd = minutesFromClock(day.endTime);
      const interval = nonNegativeMinutes(day.slotStartIntervalMinutes, 15);
      if (windowStart === null || windowEnd === null || windowStart >= windowEnd || interval <= 0) {
        continue;
      }
      const exclusions = day.generatedExclusionRanges ?? day.exclusionRanges;
      for (let start = windowStart; start + durationMinutes <= windowEnd; start += interval) {
        const end = start + durationMinutes;
        if (!overlapsExclusion(start, end, exclusions)) {
          candidates.push({start: clockFromMinutes(start), end: clockFromMinutes(end)});
        }
      }
    } else {
      const rawSlots = Array.isArray(day.timeSlots) ? day.timeSlots : [];
      for (const raw of rawSlots) {
        if (!raw || typeof raw !== "object") continue;
        const value = raw as Record<string, unknown>;
        if (value.enabled !== true || value.sessionType !== sessionType) continue;
        const start = optionalString(value.startTime);
        const end = optionalString(value.endTime);
        if (start && end) candidates.push({start, end});
      }
    }

    const breaks = day.breakMinutesBySessionType && typeof day.breakMinutesBySessionType === "object"
      ? day.breakMinutesBySessionType as Record<string, unknown>
      : schedule.breakMinutesBySessionType && typeof schedule.breakMinutesBySessionType === "object"
        ? schedule.breakMinutesBySessionType as Record<string, unknown>
        : {};
    const breakMinutes = nonNegativeMinutes(
      breaks[sessionType],
      DEFAULT_BREAKS[sessionType] ?? 0,
    );
    for (const candidate of candidates) {
      const slotStart = localDateTime(teacherLocalDate, candidate.start, teacherTimeZoneId);
      const rawEnd = localDateTime(teacherLocalDate, candidate.end, teacherTimeZoneId);
      // The trusted plan duration defines the absolute end for every new
      // booking. A legacy fixed slot is exposed only when its stored duration
      // agrees with that trusted duration.
      const slotEnd = slotStart
        ? new Date(slotStart.getTime() + durationMinutes * 60_000)
        : null;
      if (schemaVersion < 2 && slotEnd &&
          (!rawEnd || Math.abs(rawEnd.getTime() - slotEnd.getTime()) > 60_000)) {
        continue;
      }
      if (!slotStart || !slotEnd || slotEnd <= slotStart || slotStart <= now ||
          slotStart >= endOfWindow ||
          intervalOccupied(slotStart, slotEnd, breakMinutes, occupied)) {
        continue;
      }
      slots.push({
        slotStartUtc: slotStart.toISOString(),
        slotEndUtc: slotEnd.toISOString(),
        teacherLocalDate,
        teacherLocalTimeSlot:
          `${teacherLocalSnapshot(slotStart, teacherTimeZoneId).localTime} - ` +
          teacherLocalSnapshot(slotEnd, teacherTimeZoneId).localTime,
        teacherTimeZoneId,
        availabilityDocId: availabilityDoc.id,
        sessionType,
      });
    }
  }

  slots.sort((a, b) => String(a.slotStartUtc).localeCompare(String(b.slotStartUtc)));
  return {
    bookingTimeZoneVersion: 1,
    teacherTimeZoneId,
    windowStartUtc: now.toISOString(),
    windowEndUtc: endOfWindow.toISOString(),
    slots,
  };
});
