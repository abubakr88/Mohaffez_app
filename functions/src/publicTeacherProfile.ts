import * as functions from "firebase-functions";
import { db } from "./utils/admin";

const MAX_PUBLIC_AVAILABILITY_DAYS = 14;

function requireString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `${field} is required`,
      { code: `invalid-${field}` },
    );
  }
  return value.trim();
}

function safeString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function safeNumber(value: unknown, fallback = 0): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function publicUserProfile(
  id: string,
  data: FirebaseFirestore.DocumentData,
): Record<string, unknown> {
  return {
    uid: id,
    name: safeString(data.name) ?? "محفظ",
    role: "mohaffez",
    status: data.status,
    specialization: safeString(data.specialization),
    bio: safeString(data.bio),
    photoUrl: safeString(data.photoUrl),
    youtubeVideoUrl: safeString(data.youtubeVideoUrl),
    introVideoUrl: safeString(data.introVideoUrl),
    videoUrl: safeString(data.videoUrl),
    rating: safeNumber(data.rating),
    reviewCount: Math.max(0, Math.trunc(safeNumber(data.reviewCount))),
    completedSessionsCount: Math.max(
      0,
      Math.trunc(safeNumber(data.completedSessionsCount)),
    ),
    studentsServedCount: Math.max(
      0,
      Math.trunc(safeNumber(data.studentsServedCount)),
    ),
    acceptingNewBookings: data.acceptingNewBookings !== false,
    trialSessionEnabled: data.trialSessionEnabled === true,
    trialSessionDurationMinutes:
      typeof data.trialSessionDurationMinutes === "number"
        ? data.trialSessionDurationMinutes
        : 30,
    badges: data.badges ?? {},
  };
}

function publicCredential(
  id: string,
  data: FirebaseFirestore.DocumentData,
): Record<string, unknown> {
  return {
    id,
    type: safeString(data.type) ?? "ijazah",
    title: safeString(data.title),
    organization: safeString(data.organization),
    imageUrls: Array.isArray(data.imageUrls)
      ? data.imageUrls.filter((url) => typeof url === "string")
      : [],
    issueDate: data.issueDate?.toDate?.()?.toISOString?.() ?? null,
    status: "approved",
  };
}

function publicPricingPlan(
  id: string,
  data: FirebaseFirestore.DocumentData,
): Record<string, unknown> {
  return {
    id,
    mohaffezId: safeString(data.mohaffezId),
    title: safeString(data.title) ?? "خطة سعر",
    type: safeString(data.type) ?? "single",
    mode: safeString(data.mode) ?? "online",
    priceEGP: safeNumber(data.priceEGP),
    sessionsCount: Math.max(0, Math.trunc(safeNumber(data.sessionsCount))),
    sessionDurationMinutes:
      typeof data.sessionDurationMinutes === "number"
        ? Math.trunc(data.sessionDurationMinutes)
        : null,
    validityDays:
      typeof data.validityDays === "number" ? data.validityDays : null,
    sessionsPerWeek:
      typeof data.sessionsPerWeek === "number" ? data.sessionsPerWeek : null,
    isActive: true,
    isFreeTrialAvailable: data.isFreeTrialAvailable === true,
    description: safeString(data.description),
  };
}

function publicAvailability(
  id: string,
  data: FirebaseFirestore.DocumentData,
): Record<string, unknown> {
  const rawSlots = Array.isArray(data.timeSlots) ? data.timeSlots : [];
  const timeSlots = rawSlots
    .filter((slot) => slot && typeof slot === "object" && slot.enabled === true)
    .map((slot) => ({
      enabled: true,
      startTime: safeString(slot.startTime),
      endTime: safeString(slot.endTime),
      sessionType: safeString(slot.sessionType) ?? "online",
    }))
    .filter((slot) => slot.startTime && slot.endTime);

  return {
    id,
    dayOfWeek: data.dayOfWeek,
    scheduleSchemaVersion:
      typeof data.scheduleSchemaVersion === "number"
        ? Math.trunc(data.scheduleSchemaVersion)
        : 1,
    scheduleMode: safeString(data.scheduleMode),
    startTime: safeString(data.startTime),
    endTime: safeString(data.endTime),
    sessionTypes: Array.isArray(data.sessionTypes)
      ? data.sessionTypes.filter((type) => typeof type === "string")
      : [],
    legacySessionDurationMinutes:
      typeof data.legacySessionDurationMinutes === "number"
        ? Math.trunc(data.legacySessionDurationMinutes)
        : null,
    slotStartIntervalMinutes:
      typeof data.slotStartIntervalMinutes === "number"
        ? Math.trunc(data.slotStartIntervalMinutes)
        : 15,
    breakMinutesBySessionType:
      data.breakMinutesBySessionType &&
      typeof data.breakMinutesBySessionType === "object"
        ? data.breakMinutesBySessionType
        : {},
    exclusionRanges: Array.isArray(data.exclusionRanges)
      ? data.exclusionRanges
      : [],
    generatedExclusionRanges: Array.isArray(data.generatedExclusionRanges)
      ? data.generatedExclusionRanges
      : [],
    timeSlots,
  };
}

export const getPublicTeacherProfile = functions.https.onCall(async (data) => {
  const mohaffezId = requireString(data?.mohaffezId, "mohaffezId");

  const userRef = db.collection("users").doc(mohaffezId);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError("not-found", "teacher-not-found", {
      code: "teacher-not-found",
    });
  }

  const userData = userDoc.data() ?? {};
  if (userData.role !== "mohaffez" || userData.status !== "active") {
    throw new functions.https.HttpsError("not-found", "teacher-not-public", {
      code: "teacher-not-public",
    });
  }

  const [credentialsSnapshot, plansSnapshot, availabilitySnapshot] =
    await Promise.all([
      userRef.collection("credentials").get(),
      userRef.collection("pricingPlans").get(),
      userRef
        .collection("availability")
        .limit(MAX_PUBLIC_AVAILABILITY_DAYS)
        .get(),
    ]);

  const credentials = credentialsSnapshot.docs
    .filter((doc) => doc.data().status === "approved")
    .map((doc) => publicCredential(doc.id, doc.data()));

  const plans = plansSnapshot.docs
    .filter((doc) => doc.data().isActive === true)
    .map((doc) => publicPricingPlan(doc.id, doc.data()))
    .sort(
      (a, b) =>
        safeNumber(a.priceEGP as number | undefined) -
        safeNumber(b.priceEGP as number | undefined),
    );

  return {
    profile: publicUserProfile(userDoc.id, userData),
    credentials,
    plans,
    availability: availabilitySnapshot.docs
      .map((doc) => publicAvailability(doc.id, doc.data()))
      .filter((day) => {
        if (day.scheduleSchemaVersion === 2) {
          return Boolean(day.startTime) &&
            Boolean(day.endTime) &&
            (day.sessionTypes as unknown[]).length > 0;
        }
        return (day.timeSlots as unknown[]).length > 0;
      }),
    stats: {
      completedSessions: Math.max(
        0,
        Math.trunc(safeNumber(userData.completedSessionsCount)),
      ),
      uniqueStudents: Math.max(
        0,
        Math.trunc(safeNumber(userData.studentsServedCount)),
      ),
    },
  };
});
