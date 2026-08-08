// CHANGES vs original:
// 1. Added: validityDays extraction + rawPlanType/isBundlePlan computation after destructure
// 2. Fixed: initialStatus — bundle directpayment requests start at PENDING (not AWAITING_PAYMENT)
//    because teacher-first rule applies to all bundles regardless of payment method
// 3. Added: validityDays to transaction.set()
// 4. Updated: notification title/body in 4f to reflect bundle vs single
// 5. Added: active bundle check to prevent duplicate active bundle requests (NEW)
// FIX-TS6133: subscriptionId destructured variable now used in both diagnostic log
//             and transaction.set() — eliminates TS6133 'declared but never read' error.
// All other logic (slot lock, conflict guard, availability disable, etc.) is UNTOUCHED

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db, FieldValue } from "../utils/admin";
import { isAcceptingNewBookings } from "../teacherBookingPolicy";
import {
  audienceAgeGroup,
  teacherAcceptsAudience,
} from "../teacherAudiencePolicy";

const STATUS = {
  PENDING: "pending",
  AWAITING_PAYMENT: "awaitingpayment",
  AWAITING_DIRECT: "awaitingdirectpaymentconfirmation",
  ACCEPTED: "accepted",
  REJECTED: "rejected",
  CANCELLED: "cancelled",
} as const;

const SUPPORTED_SESSION_DURATIONS = new Set([15, 30, 45, 60, 75, 90, 120]);
const DEFAULT_SESSION_DURATION_MINUTES = 45;
const DEFAULT_BREAK_MINUTES: Record<string, number> = {
  online: 10,
  mosque: 15,
  home: 30,
};

function supportedDuration(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  const duration = Math.trunc(value);
  return SUPPORTED_SESSION_DURATIONS.has(duration) ? duration : null;
}

// Existing schedules and purchased subscriptions may contain durations that
// predate the new plan choices (for example 20 minutes). Keep those trusted
// records usable without offering the old values for newly-created plans.
function compatibleStoredDuration(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  const duration = Math.trunc(value);
  return duration >= 5 && duration <= 240 ? duration : null;
}

function nonNegativeMinutes(value: unknown, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.max(0, Math.min(120, Math.trunc(value)));
}

function minutesFromClock(value: unknown): number | null {
  if (typeof value !== "string") return null;
  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

function preferredStartMinutes(value: string): number | null {
  const normalized = value.replace(/[\u2013\u2014]/g, "-");
  return minutesFromClock(normalized.split("-")[0]?.trim());
}

function intervalsOverlap(
  firstStart: Date,
  firstEnd: Date,
  firstBreakMinutes: number,
  secondStart: Date,
  secondEnd: Date,
  secondBreakMinutes: number,
): boolean {
  const firstReservedEnd = new Date(
    firstEnd.getTime() + firstBreakMinutes * 60 * 1000,
  );
  const secondReservedEnd = new Date(
    secondEnd.getTime() + secondBreakMinutes * 60 * 1000,
  );
  return firstStart < secondReservedEnd && secondStart < firstReservedEnd;
}

function timestampDate(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function rangeOverlapsClock(
  startMinutes: number,
  endMinutes: number,
  ranges: unknown,
): boolean {
  if (!Array.isArray(ranges)) return false;
  return ranges.some((range) => {
    if (!range || typeof range !== "object") return false;
    const record = range as Record<string, unknown>;
    const rangeStart = minutesFromClock(record.start);
    const rangeEnd = minutesFromClock(record.end);
    return (
      rangeStart !== null &&
      rangeEnd !== null &&
      startMinutes < rangeEnd &&
      endMinutes > rangeStart
    );
  });
}

function normalizeTimeSlot(raw: string): string {
  // FIXED: BUG-5 - strip both hyphens AND en-dashes
  return raw.replace(/\s/g, "").replace(/[\u2013\u2014]/g, "-");
}

function parseFlutterDate(iso: string): Date {
  if (!iso.endsWith("Z") && !/[+\-]\d{2}:\d{2}$/.test(iso)) {
    return new Date(iso + "Z");
  }
  return new Date(iso);
}

function optionalString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

function optionalTimestamp(value: unknown): FirebaseFirestore.Timestamp | null {
  if (value instanceof admin.firestore.Timestamp) return value;
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = parseFlutterDate(value.trim());
    if (!isNaN(parsed.getTime())) {
      return admin.firestore.Timestamp.fromDate(parsed);
    }
  }
  return null;
}

function calculateAgeFromTimestamp(
  birthDate: FirebaseFirestore.Timestamp | null,
): number | null {
  if (!birthDate) return null;
  const dob = birthDate.toDate();
  const today = new Date();
  let age = today.getUTCFullYear() - dob.getUTCFullYear();
  const monthDiff = today.getUTCMonth() - dob.getUTCMonth();
  if (
    monthDiff < 0 ||
    (monthDiff === 0 && today.getUTCDate() < dob.getUTCDate())
  ) {
    age--;
  }
  return age >= 0 && age <= 120 ? age : null;
}

export const createSessionRequest = functions.https.onCall(
  async (data, context) => {
    const fallbackIdToken =
      typeof data?.idToken === "string" ? data.idToken : null;
    let studentId: string | null = context.auth?.uid ?? null;

    // ── 0. DIAGNOSTIC LOG (remove after issue resolved) ───────────────────
    functions.logger.info("createSessionRequest invoked", {
      hasAuth: !!context.auth,
      uid: context.auth?.uid ?? "NONE",
      hasAppCheck: !!(context as any).app,
      rawAuthHeader: !!(context as any).rawRequest?.headers?.authorization,
      hasFallbackIdToken: !!fallbackIdToken,
    });

    // ── 1. Auth ────────────────────────────────────────────────────────────
    if (!studentId && fallbackIdToken) {
      try {
        const decoded = await admin.auth().verifyIdToken(fallbackIdToken);
        studentId = decoded.uid;
        functions.logger.warn(
          "createSessionRequest: using fallback idToken verification",
          { uid: studentId },
        );
      } catch (e) {
        functions.logger.error(
          "createSessionRequest: fallback idToken verification failed",
          { error: e instanceof Error ? e.message : String(e) },
        );
      }
    }

    if (!studentId) {
      functions.logger.error(
        "createSessionRequest: UNAUTHENTICATED - no context.auth and no valid fallback token",
        { headers: JSON.stringify((context as any).rawRequest?.headers ?? {}) },
      );
      throw new functions.https.HttpsError("unauthenticated", "Login required");
    }

    // ── 2. Destructure ─────────────────────────────────────────────────────
    const {
      mohaffezId,
      studentName,
      mohaffezName,
      sessionType,
      preferredProvider,
      preferredTimeSlot,
      slotDate,
      slotStart,
      slotEnd,
      imamAddressText,
      imamAddressLat,
      imamAddressLng,
      mohaffezPhone,
      studentPhone,
      subscriptionId, // FIX-TS6133: now consumed below (log + Firestore write)
      requiresPaymentOnAcceptance,
      selectedPaymentMethod,
      slotLockId,
    } = data;

    // ── NEW: plan fields with safe defaults ────────────────────────────────
    const rawPlanType: string =
      (data.planType as string | undefined) ?? "single";
    const isBundlePlan =
      rawPlanType === "bundle" || rawPlanType === "subscription";
    const validityDays: number | null =
      typeof data.validityDays === "number" ? data.validityDays : null;
    const clientSessionDurationMinutes = compatibleStoredDuration(
      data.sessionDurationMinutes,
    );
    const displayAmount: number | null =
      typeof data.displayAmount === "number" ? data.displayAmount : null;
    const fxRateToEGP: number | null =
      typeof data.fxRateToEGP === "number" ? data.fxRateToEGP : null;
    const chargedAmountEGP: number | null =
      typeof data.chargedAmountEGP === "number" ? data.chargedAmountEGP : null;
    const studentProfileBirthDate = optionalTimestamp(
      data.studentProfileBirthDate,
    );
    const canonicalStudentAge = calculateAgeFromTimestamp(
      studentProfileBirthDate,
    );
    // ── 3. Validate ────────────────────────────────────────────────────────
    if (
      !mohaffezId ||
      !studentName ||
      !mohaffezName ||
      !sessionType ||
      !preferredTimeSlot ||
      !slotDate ||
      !slotStart ||
      !slotEnd
    ) {
      functions.logger.error("createSessionRequest: missing required fields", {
        studentId,
        mohaffezId,
        hasStudentName: !!studentName,
        hasMohaffezName: !!mohaffezName,
        sessionType,
        preferredTimeSlot,
        slotDate,
      });
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields",
      );
    }

    const slotDateObj = parseFlutterDate(slotDate);
    const slotStartObj = parseFlutterDate(slotStart);
    const slotEndObj = parseFlutterDate(slotEnd);

    if (
      isNaN(slotDateObj.getTime()) ||
      isNaN(slotStartObj.getTime()) ||
      isNaN(slotEndObj.getTime())
    ) {
      functions.logger.error("createSessionRequest: invalid date values", {
        slotDate,
        slotStart,
        slotEnd,
      });
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid date values provided",
      );
    }

    if (data.studentId && data.studentId !== studentId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "studentId in payload does not match authenticated user",
      );
    }

    functions.logger.info("createSessionRequest: validation passed", {
      studentId,
      mohaffezId,
      sessionType,
      preferredTimeSlot,
      slotDate,
      hasSlotLockId: !!slotLockId,
      selectedPaymentMethod,
      requiresPaymentOnAcceptance,
      rawPlanType,
      isBundlePlan,
    });

    // ────────────────────────────────────────────────────────────────────────
    // ── NEW CHECK: Prevent duplicate active bundle requests ────────────────
    // ────────────────────────────────────────────────────────────────────────
    // BUG FIX: Only check for duplicates when BUYING a new bundle
    // (requiresPaymentOnAcceptance = true). When USING an existing bundle
    // (Path A), we skip this check because the student SHOULD have an active bundle.
    const isBuyingNewBundle =
      isBundlePlan && requiresPaymentOnAcceptance === true;

    // LOGGING: Path identification for debugging
    functions.logger.info("createSessionRequest: Path identification", {
      isBundlePlan,
      requiresPaymentOnAcceptance: requiresPaymentOnAcceptance ?? false,
      hasSubscriptionId: !!subscriptionId,
      isBuyingNewBundle,
      path: isBuyingNewBundle
        ? "PATH_B_BUY_NEW_BUNDLE"
        : isBundlePlan
          ? "PATH_A_USE_EXISTING_BUNDLE"
          : "PATH_C_SINGLE_SESSION",
      studentId,
      mohaffezId,
      sessionType,
    });

    if (isBuyingNewBundle) {
      // Query for an active subscription of the same type for this student+teacher
      const activeSubsQuery = db
        .collection("subscriptions")
        .where("studentId", "==", studentId)
        .where("mohaffezId", "==", mohaffezId)
        .where("sessionType", "==", sessionType)
        .where("status", "==", "active")
        .where("remainingSessions", ">", 0)
        .limit(1);

      const activeSnap = await activeSubsQuery.get();

      functions.logger.info("createSessionRequest: Duplicate bundle check", {
        foundExistingBundle: !activeSnap.empty,
        existingBundleCount: activeSnap.size,
        studentId,
        mohaffezId,
        sessionType,
      });

      if (!activeSnap.empty) {
        functions.logger.warn(
          "createSessionRequest: BLOCKED - duplicate active bundle exists",
          {
            studentId,
            mohaffezId,
            sessionType,
            existingBundleId: activeSnap.docs[0]?.id,
          },
        );
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "لديك باقة نشطة بالفعل لهذا النوع من الجلسات",
        );
      }
    }

    // ── 4. Transaction ─────────────────────────────────────────────────────
    return db.runTransaction(async (transaction) => {
      let resolvedStudentName = studentName;
      let resolvedGuardianId = optionalString(data.guardianId) ?? studentId;
      let resolvedGuardianName = optionalString(data.guardianName);
      let resolvedStudentProfileId = optionalString(data.studentProfileId);
      let resolvedStudentProfileName = optionalString(data.studentProfileName);
      let resolvedStudentProfileGender = optionalString(
        data.studentProfileGender,
      );
      let resolvedStudentProfilePhotoUrl = optionalString(
        data.studentProfilePhotoUrl,
      );
      let resolvedStudentProfileBirthDate = studentProfileBirthDate;
      let resolvedStudentAge =
        canonicalStudentAge ??
        (typeof data.studentAge === "number" ? data.studentAge : null);
      let resolvedPlanId = optionalString(data.planId);
      let resolvedPlanTitle = optionalString(data.planTitle);
      let lockRef: FirebaseFirestore.DocumentReference | null = null;
      let availabilityRef: FirebaseFirestore.DocumentReference | null = null;
      let availabilityData: FirebaseFirestore.DocumentData | null = null;
      let updatedSlots: Record<string, unknown>[] | null = null;
      let subscriptionDurationBackfillRef: FirebaseFirestore.DocumentReference | null =
        null;
      let bookingCalendarRef: FirebaseFirestore.DocumentReference | null = null;
      let bookingCalendarIntervals: Record<string, unknown>[] = [];

      const configSnap = await transaction.get(
        db.collection("systemConfig").doc("global"),
      );
      const systemConfig = configSnap.data() ?? {};
      const variablePlanDurationEnabled =
        systemConfig.variablePlanSessionDurationEnabled === true;

      const teacherSnap = await transaction.get(
        db.collection("users").doc(mohaffezId),
      );
      const teacherData = teacherSnap.data() ?? {};
      if (!isAcceptingNewBookings(teacherData)) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "المحفظ لا يستقبل طلبات حجز جديدة حاليًا",
        );
      }

      // ── 4a. Validate slot lock ─────────────────────────────────────────
      if (slotLockId) {
        lockRef = db.collection("slotLocks").doc(slotLockId);
        const lockSnap = await transaction.get(lockRef);

        if (!lockSnap.exists) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "الموعد المحجوز مؤقتاً غير موجود أو انتهت صلاحيته",
          );
        }

        const lock = lockSnap.data()!;

        if (lock.released === true) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "تم تحرير هذا الموعد بالفعل",
          );
        }

        const now = new Date();
        if (lock.expiresAt && lock.expiresAt.toDate() < now) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "انتهت صلاحية حجز الموعد المؤقت. الرجاء اختيار موعد آخر",
          );
        }

        if (lock.mohaffezId !== mohaffezId) {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "الموعد المحجوز لا ينتمي لهذا المحفظ",
          );
        }

        const availabilityDocId =
          typeof lock.availabilityDocId === "string"
            ? lock.availabilityDocId
            : null;
        const lockTimeSlot =
          typeof lock.timeSlot === "string" ? lock.timeSlot : null;
        const lockSessionType =
          typeof lock.sessionType === "string" ? lock.sessionType : null;

        if (availabilityDocId && lockTimeSlot && lockSessionType) {
          availabilityRef = db
            .collection("users")
            .doc(mohaffezId)
            .collection("availability")
            .doc(availabilityDocId);

          const availabilitySnap = await transaction.get(availabilityRef);
          if (availabilitySnap.exists) {
            availabilityData = availabilitySnap.data() ?? {};
            const slots: Record<string, unknown>[] = Array.isArray(
              availabilityData.timeSlots,
            )
              ? (availabilityData.timeSlots as Record<string, unknown>[])
              : [];

            const selectedSlot = normalizeTimeSlot(lockTimeSlot);
            let changed = false;

            updatedSlots =
              variablePlanDurationEnabled &&
              availabilityData.scheduleSchemaVersion === 2
                ? null
                : slots.map((slot) => {
                    const start =
                      typeof slot.startTime === "string" ? slot.startTime : "";
                    const end =
                      typeof slot.endTime === "string" ? slot.endTime : "";
                    const slotTime = normalizeTimeSlot(`${start}-${end}`);
                    if (
                      slotTime === selectedSlot &&
                      slot.sessionType === lockSessionType
                    ) {
                      changed = true;
                      return {
                        ...slot,
                        enabled: false,
                        lockedBy: null,
                        lockId: null,
                        lockedAt: null,
                      };
                    }
                    return slot;
                  });

            // FIXED: BUG-5 - Warn if slot disable was skipped due to mismatch
            if (
              (!variablePlanDurationEnabled ||
                availabilityData.scheduleSchemaVersion !== 2) &&
              !changed
            ) {
              functions.logger.warn(
                "createSessionRequest: slot disable skipped — no matching slot found",
                {
                  lockTimeSlot,
                  lockSessionType,
                  availableSlots: slots.map(
                    (s: any) => `${s.startTime}-${s.endTime}:${s.sessionType}`,
                  ),
                },
              );
              updatedSlots = null;
            }
          }
        }
      }

      // Resolve duration and break from trusted Firestore documents. Client
      // values are used only as a compatibility fallback for legacy records.
      const scheduleSettingsRef = db
        .collection("users")
        .doc(mohaffezId)
        .collection("settings")
        .doc("schedule");
      const scheduleSettingsSnap = await transaction.get(scheduleSettingsRef);
      const scheduleSettings = scheduleSettingsSnap.data() ?? {};

      let sessionDurationMinutes: number | null = null;
      if (typeof subscriptionId === "string" && subscriptionId.length > 0) {
        const subscriptionRef = db
          .collection("subscriptions")
          .doc(subscriptionId);
        const subscriptionSnap = await transaction.get(subscriptionRef);
        if (!subscriptionSnap.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "الباقة المختارة غير موجودة",
          );
        }
        const subscription = subscriptionSnap.data() ?? {};
        if (
          subscription.studentId !== studentId ||
          subscription.mohaffezId !== mohaffezId ||
          (subscription.sessionType && subscription.sessionType !== sessionType)
        ) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "الباقة لا تخص هذا الحجز",
          );
        }
        const remainingSessions = Number(subscription.remainingSessions ?? 0);
        const subscriptionExpiry = timestampDate(subscription.expiryDate);
        if (
          subscription.status !== "active" ||
          !Number.isFinite(remainingSessions) ||
          remainingSessions <= 0 ||
          (subscriptionExpiry != null &&
            subscriptionExpiry.getTime() < Date.now())
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "الباقة المختارة غير نشطة أو انتهت صلاحيتها",
          );
        }
        resolvedGuardianId =
          optionalString(subscription.guardianId) ?? subscription.studentId;
        resolvedGuardianName = optionalString(subscription.guardianName);
        resolvedStudentProfileId = optionalString(
          subscription.studentProfileId,
        );
        resolvedStudentProfileName = optionalString(
          subscription.studentProfileName,
        );
        resolvedStudentProfileGender = optionalString(
          subscription.studentProfileGender,
        );
        resolvedStudentProfilePhotoUrl = optionalString(
          subscription.studentProfilePhotoUrl,
        );
        resolvedStudentProfileBirthDate = optionalTimestamp(
          subscription.studentProfileBirthDate,
        );
        resolvedStudentAge =
          calculateAgeFromTimestamp(resolvedStudentProfileBirthDate) ??
          (typeof subscription.studentAge === "number"
            ? subscription.studentAge
            : null);
        resolvedStudentName =
          resolvedStudentProfileName ??
          optionalString(subscription.studentName) ??
          studentName;
        resolvedPlanId = optionalString(subscription.planId);
        resolvedPlanTitle = optionalString(subscription.planTitle);
        if (variablePlanDurationEnabled) {
          const storedSubscriptionDuration = compatibleStoredDuration(
            subscription.sessionDurationMinutes,
          );
          sessionDurationMinutes = storedSubscriptionDuration;

          const subscriptionPlanId = optionalString(subscription.planId);
          if (sessionDurationMinutes === null && subscriptionPlanId) {
            const subscriptionPlanRef = db
              .collection("users")
              .doc(mohaffezId)
              .collection("pricingPlans")
              .doc(subscriptionPlanId);
            const subscriptionPlanSnap =
              await transaction.get(subscriptionPlanRef);
            sessionDurationMinutes = supportedDuration(
              subscriptionPlanSnap.data()?.sessionDurationMinutes,
            );
          }

          if (storedSubscriptionDuration === null) {
            subscriptionDurationBackfillRef = subscriptionRef;
          }
        }
      } else if (typeof data.planId === "string" && data.planId.length > 0) {
        const planRef = db
          .collection("users")
          .doc(mohaffezId)
          .collection("pricingPlans")
          .doc(data.planId);
        const planSnap = await transaction.get(planRef);
        if (!planSnap.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "الخطة السعرية المختارة غير موجودة",
          );
        }
        const plan = planSnap.data() ?? {};
        if (
          plan.isActive !== true ||
          (plan.mode && plan.mode !== sessionType)
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "الخطة السعرية غير متاحة لهذا النوع من الجلسات",
          );
        }
        if (variablePlanDurationEnabled) {
          sessionDurationMinutes = supportedDuration(
            plan.sessionDurationMinutes,
          );
        }
      }

      if (systemConfig.discoveryAudienceMatchingEnabled !== false) {
        const studentAccountSnap = await transaction.get(
          db.collection("users").doc(studentId),
        );
        const studentAccount = studentAccountSnap.data() ?? {};
        const studentAccountRole = optionalString(studentAccount.role)
          ?.toLowerCase();
        let canonicalLearner = studentAccount;

        if (studentAccountRole === "parent") {
          if (!resolvedStudentProfileId ||
              resolvedStudentProfileId === "self") {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "اختر ملف الطالب وأكمل بياناته قبل الحجز",
            );
          }
          const learnerProfileSnap = await transaction.get(
            db.collection("users")
              .doc(studentId)
              .collection("studentProfiles")
              .doc(resolvedStudentProfileId),
          );
          if (!learnerProfileSnap.exists ||
              learnerProfileSnap.data()?.isActive === false) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "ملف الطالب المختار غير متاح",
            );
          }
          canonicalLearner = learnerProfileSnap.data() ?? {};
        }

        const canonicalGender = optionalString(canonicalLearner.gender)
          ?.toLowerCase();
        const canonicalBirthDate = optionalTimestamp(
          canonicalLearner.dateOfBirth,
        );
        const canonicalAge = calculateAgeFromTimestamp(canonicalBirthDate);
        if ((canonicalGender !== "male" && canonicalGender !== "female") ||
            canonicalAge === null || canonicalBirthDate === null) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "أكمل نوع الطالب وتاريخ ميلاده قبل الحجز",
          );
        }
        const ageGroup = audienceAgeGroup(canonicalAge, systemConfig);
        const allowIncomplete =
          systemConfig.allowIncompleteTeacherAudience !== false;
        if (!teacherAcceptsAudience(
          teacherData,
          ageGroup,
          canonicalGender,
          allowIncomplete,
        )) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "هذا المحفّظ لا يدرّس الفئة العمرية والنوع المحددين",
          );
        }

        resolvedStudentProfileGender = canonicalGender;
        resolvedStudentProfileBirthDate = canonicalBirthDate;
        resolvedStudentAge = canonicalAge;
        resolvedStudentProfileName = optionalString(canonicalLearner.name) ??
          resolvedStudentProfileName;
        resolvedStudentName = resolvedStudentProfileName ??
          optionalString(canonicalLearner.name) ??
          resolvedStudentName;
      }

      sessionDurationMinutes = variablePlanDurationEnabled
        ? (sessionDurationMinutes ??
          compatibleStoredDuration(scheduleSettings.sessionDuration) ??
          clientSessionDurationMinutes ??
          DEFAULT_SESSION_DURATION_MINUTES)
        : (compatibleStoredDuration(scheduleSettings.sessionDuration) ??
          clientSessionDurationMinutes ??
          DEFAULT_SESSION_DURATION_MINUTES);

      const breakMap =
        scheduleSettings.breakMinutesBySessionType &&
        typeof scheduleSettings.breakMinutesBySessionType === "object"
          ? (scheduleSettings.breakMinutesBySessionType as Record<
              string,
              unknown
            >)
          : {};
      const hasLegacyBreak =
        typeof scheduleSettings.breakMinutes === "number" &&
        Number.isFinite(scheduleSettings.breakMinutes);
      const legacyBreak = hasLegacyBreak
        ? nonNegativeMinutes(scheduleSettings.breakMinutes, 0)
        : null;
      const breakMinutesAfter = variablePlanDurationEnabled
        ? nonNegativeMinutes(
            breakMap[sessionType],
            legacyBreak ?? DEFAULT_BREAK_MINUTES[sessionType] ?? 0,
          )
        : 0;

      const canonicalSlotEndObj = new Date(
        slotStartObj.getTime() + sessionDurationMinutes * 60 * 1000,
      );
      if (
        slotStartObj >= canonicalSlotEndObj ||
        Math.abs(slotEndObj.getTime() - canonicalSlotEndObj.getTime()) >
          60 * 1000
      ) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "مدة الموعد لا تطابق مدة الخطة المختارة. اختر الموعد مرة أخرى.",
        );
      }

      if (!availabilityData) {
        const jsDay = slotDateObj.getUTCDay();
        const dayOfWeek = jsDay === 0 ? 7 : jsDay;
        const availabilityQuery = db
          .collection("users")
          .doc(mohaffezId)
          .collection("availability")
          .where("dayOfWeek", "==", dayOfWeek)
          .limit(1);
        const availabilitySnap = await transaction.get(availabilityQuery);
        if (!availabilitySnap.empty) {
          availabilityRef = availabilitySnap.docs[0].ref;
          availabilityData = availabilitySnap.docs[0].data();
        }
      }

      if (
        variablePlanDurationEnabled &&
        availabilityData?.scheduleSchemaVersion === 2
      ) {
        const availableTypes = Array.isArray(availabilityData.sessionTypes)
          ? availabilityData.sessionTypes
          : [];
        const startMinutes = preferredStartMinutes(preferredTimeSlot);
        const windowStart = minutesFromClock(availabilityData.startTime);
        const windowEnd = minutesFromClock(availabilityData.endTime);
        const interval = nonNegativeMinutes(
          availabilityData.slotStartIntervalMinutes,
          15,
        );
        const endMinutes =
          startMinutes === null ? null : startMinutes + sessionDurationMinutes;
        const exclusions =
          availabilityData.generatedExclusionRanges ??
          availabilityData.exclusionRanges;

        if (
          !availableTypes.includes(sessionType) ||
          startMinutes === null ||
          endMinutes === null ||
          windowStart === null ||
          windowEnd === null ||
          startMinutes < windowStart ||
          endMinutes > windowEnd ||
          interval <= 0 ||
          startMinutes % interval !== 0 ||
          rangeOverlapsClock(startMinutes, endMinutes, exclusions)
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "هذا الموعد غير متاح ضمن جدول المحفظ الحالي",
          );
        }
      }

      // ── 4b. Conflict guard ─────────────────────────────────────────────
      // FIX-BOOKING-1: Guard against all live statuses, not just PENDING.
      // Required Firestore composite index: (mohaffezId ASC, status ASC, slotDate ASC)
      // Read one deterministic document for the teacher/day before checking
      // request overlaps. Updating this document in the same transaction makes
      // concurrent bookings contend on a shared version, including when the
      // overlap query was initially empty. The request query below remains the
      // source of truth; this document is only the transaction mutex and UI
      // projection.
      if (variablePlanDurationEnabled) {
        const calendarDateId = slotDateObj.toISOString().slice(0, 10);
        bookingCalendarRef = db
          .collection("users")
          .doc(mohaffezId)
          .collection("bookingCalendar")
          .doc(calendarDateId);
        const bookingCalendarSnap = await transaction.get(bookingCalendarRef);
        const rawIntervals = bookingCalendarSnap.data()?.intervals;
        bookingCalendarIntervals = Array.isArray(rawIntervals)
          ? rawIntervals
              .filter(
                (interval): interval is Record<string, unknown> =>
                  interval != null &&
                  typeof interval === "object" &&
                  !Array.isArray(interval),
              )
              .map((interval) => ({ ...interval }))
          : [];
      }

      const LIVE_STATUSES = [
        STATUS.PENDING,
        STATUS.AWAITING_PAYMENT,
        STATUS.AWAITING_DIRECT,
        STATUS.ACCEPTED,
      ] as const;

      const conflictQuery = db
        .collection("sessionRequests")
        .where("mohaffezId", "==", mohaffezId)
        .where("status", "in", [...LIVE_STATUSES])
        .where(
          "slotDate",
          "==",
          admin.firestore.Timestamp.fromDate(slotDateObj),
        );

      const conflictSnap = await transaction.get(conflictQuery);

      const normalizedSlot = normalizeTimeSlot(preferredTimeSlot);
      let duplicate: FirebaseFirestore.QueryDocumentSnapshot | null = null;
      let conflictingRequest: FirebaseFirestore.QueryDocumentSnapshot | null =
        null;

      for (const doc of conflictSnap.docs) {
        const existing = doc.data();
        const existingStart = timestampDate(existing.slotStart);
        let existingEnd = timestampDate(existing.slotEnd);
        const existingDuration =
          compatibleStoredDuration(existing.sessionDurationMinutes) ??
          DEFAULT_SESSION_DURATION_MINUTES;

        if (existingStart && !existingEnd) {
          existingEnd = new Date(
            existingStart.getTime() + existingDuration * 60 * 1000,
          );
        }

        let overlaps = false;
        let exactSameSlot = false;
        if (existingStart && existingEnd) {
          const existingType =
            typeof existing.sessionType === "string"
              ? existing.sessionType
              : "online";
          const existingBreak = nonNegativeMinutes(
            existing.breakMinutesAfter,
            nonNegativeMinutes(
              breakMap[existingType],
              legacyBreak ?? DEFAULT_BREAK_MINUTES[existingType] ?? 0,
            ),
          );
          overlaps = intervalsOverlap(
            existingStart,
            existingEnd,
            existingBreak,
            slotStartObj,
            canonicalSlotEndObj,
            breakMinutesAfter,
          );
          exactSameSlot =
            existingStart.getTime() === slotStartObj.getTime() &&
            existingEnd.getTime() === canonicalSlotEndObj.getTime();
        } else {
          exactSameSlot =
            normalizeTimeSlot(existing.preferredTimeSlot ?? "") ===
            normalizedSlot;
          overlaps = exactSameSlot;
        }

        if (!overlaps) continue;
        if (exactSameSlot && existing.studentId === studentId) {
          duplicate = doc;
        } else {
          conflictingRequest = doc;
        }
        break;
      }

      if (duplicate) {
        if (duplicate.data().studentId === studentId) {
          functions.logger.warn(
            "Duplicate request from same student — returning existing",
            { existingId: duplicate.id, studentId, mohaffezId },
          );
          return { success: true, requestId: duplicate.id, isDuplicate: true };
        }
      }

      if (conflictingRequest) {
        functions.logger.warn("Slot already requested by another student", {
          conflictingRequestId: conflictingRequest.id,
          mohaffezId,
          preferredTimeSlot,
          slotDate,
        });
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "هذا الموعد محجوز بالفعل. الرجاء اختيار موعد آخر",
        );
      }

      // ── 4c. Write sessionRequest ───────────────────────────────────────
      const requestRef = db.collection("sessionRequests").doc();

      // FIX-TS6133: use destructured `subscriptionId` variable (not data.subscriptionId)
      functions.logger.info("createSessionRequest saving fields", {
        selectedPaymentMethod,
        subscriptionId: subscriptionId ?? "MISSING",
      });

      // ALL session requests start at PENDING regardless of payment method.
      // Teacher accepts the slot first (PendingRequestsScreen) → student is notified
      // → status transitions to AWAITINGPAYMENT → student transfers payment →
      // studentMarkedDirectPayment → mohaffezConfirmDirectPayment → hafizSession created.
      // This enforces the teacher-first rule for every path.
      const initialStatus = STATUS.PENDING;

      transaction.set(requestRef, {
        studentId,
        mohaffezId,
        studentName: resolvedStudentName,
        guardianId: resolvedGuardianId,
        guardianName: resolvedGuardianName,
        studentProfileId: resolvedStudentProfileId,
        studentProfileName: resolvedStudentProfileName,
        studentProfileGender: resolvedStudentProfileGender,
        studentProfilePhotoUrl: resolvedStudentProfilePhotoUrl,
        studentProfileBirthDate: resolvedStudentProfileBirthDate,
        studentAge: resolvedStudentAge,
        mohaffezName,
        sessionType,
        preferredProvider:
          sessionType === "online" &&
          typeof preferredProvider === "string" &&
          preferredProvider.length > 0
            ? preferredProvider
            : null,
        preferredTimeSlot,
        slotDate: admin.firestore.Timestamp.fromDate(slotDateObj),
        slotStart: admin.firestore.Timestamp.fromDate(slotStartObj),
        slotEnd: admin.firestore.Timestamp.fromDate(canonicalSlotEndObj),
        imamAddressText: imamAddressText ?? null,
        imamAddressLat: imamAddressLat ?? null,
        imamAddressLng: imamAddressLng ?? null,
        mohaffezPhone: mohaffezPhone ?? null,
        studentPhone:
          typeof studentPhone === "string" && studentPhone.trim().length > 0
            ? studentPhone.trim()
            : null,
        subscriptionId: subscriptionId ?? null, // FIX-TS6133: was (data.subscriptionId as string) ?? null
        planId: resolvedPlanId,
        planTitle: resolvedPlanTitle,
        planType: rawPlanType,
        paymentAmount:
          typeof data.paymentAmount === "number" ? data.paymentAmount : null,
        sessionsCount:
          typeof data.sessionsCount === "number" ? data.sessionsCount : null,
        validityDays: validityDays,
        sessionDurationMinutes,
        breakMinutesAfter,
        scheduleSchemaVersion:
          variablePlanDurationEnabled &&
          availabilityData?.scheduleSchemaVersion === 2
            ? 2
            : 1,
        studentCountryCode:
          typeof data.studentCountryCode === "string"
            ? data.studentCountryCode
            : null,
        studentCountryName:
          typeof data.studentCountryName === "string"
            ? data.studentCountryName
            : null,
        displayCurrencyCode:
          typeof data.displayCurrencyCode === "string"
            ? data.displayCurrencyCode
            : null,
        displayCurrencyLabel:
          typeof data.displayCurrencyLabel === "string"
            ? data.displayCurrencyLabel
            : null,
        displayAmount,
        fxRateToEGP,
        chargedAmountEGP,
        requiresPaymentOnAcceptance:
          selectedPaymentMethod === "directpayment" && !isBundlePlan
            ? true
            : (requiresPaymentOnAcceptance ?? false),
        selectedPaymentMethod: selectedPaymentMethod ?? "pay_after_acceptance",
        slotLockId: slotLockId ?? null,
        status: initialStatus,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      if (bookingCalendarRef) {
        const slotStartTimestamp =
          admin.firestore.Timestamp.fromDate(slotStartObj);
        const slotEndTimestamp = admin.firestore.Timestamp.fromDate(
          canonicalSlotEndObj,
        );
        const reservedUntilTimestamp = admin.firestore.Timestamp.fromDate(
          new Date(
            canonicalSlotEndObj.getTime() + breakMinutesAfter * 60 * 1000,
          ),
        );
        const newKey = `${slotStartTimestamp.toMillis()}:${slotEndTimestamp.toMillis()}:${reservedUntilTimestamp.toMillis()}`;
        const nextIntervals = bookingCalendarIntervals
          .filter((interval) => {
            const start = timestampDate(interval.slotStart);
            const end = timestampDate(interval.slotEnd);
            const reservedUntil = timestampDate(interval.reservedUntil) ?? end;
            if (!start || !end || !reservedUntil) return false;
            const key = `${start.getTime()}:${end.getTime()}:${reservedUntil.getTime()}`;
            return key !== newKey;
          })
          .concat({
            slotStart: slotStartTimestamp,
            slotEnd: slotEndTimestamp,
            reservedUntil: reservedUntilTimestamp,
            sessionType,
          })
          .sort((a, b) => {
            const aStart = timestampDate(a.slotStart)?.getTime() ?? 0;
            const bStart = timestampDate(b.slotStart)?.getTime() ?? 0;
            return aStart - bStart;
          });

        transaction.set(
          bookingCalendarRef,
          {
            dateUtc: admin.firestore.Timestamp.fromDate(slotDateObj),
            intervals: nextIntervals,
            intervalCount: nextIntervals.length,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      if (subscriptionDurationBackfillRef) {
        transaction.update(subscriptionDurationBackfillRef, {
          sessionDurationMinutes,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      // ── 4d. Release slot lock ──────────────────────────────────────────
      if (lockRef) {
        transaction.update(lockRef, {
          released: true,
          releasedAt: FieldValue.serverTimestamp(),
        });
      }

      // ── 4e. Disable availability slot ─────────────────────────────────
      if (availabilityRef && updatedSlots) {
        transaction.update(availabilityRef, {
          timeSlots: updatedSlots,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      // ── 4f. Notify mohaffez ────────────────────────────────────────────
      // NEW: bundle requests show plan name/count in the notification
      const notifRef = db.collection("notifications").doc();
      transaction.set(notifRef, {
        userId: mohaffezId,
        recipientId: mohaffezId,
        senderId: studentId,
        title: isBundlePlan
          ? `طلب حزمة جديد من ${studentName}`
          : "طلب حجز جديد",
        body: isBundlePlan
          ? `${(data.planTitle as string) ?? ""} — ${data.sessionsCount ?? ""} جلسة`
          : `${studentName} يطلب حجز جلسة معك`,
        type: "sessionRequest",
        isRead: false,
        data: {
          requestId: requestRef.id,
          studentId,
          studentName,
          sessionType,
          preferredTimeSlot,
          planType: rawPlanType,
        },
        createdAt: FieldValue.serverTimestamp(),
      });

      functions.logger.info("Session request created successfully", {
        requestId: requestRef.id,
        studentId,
        mohaffezId,
        sessionType,
        preferredTimeSlot,
        rawPlanType,
        initialStatus,
      });

      return { success: true, requestId: requestRef.id };
    });
  },
);
