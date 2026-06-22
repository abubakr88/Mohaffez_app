import * as functions from "firebase-functions";
import { db, FieldValue } from "../utils/admin";
import { requireAdminAccess } from "../utils/adminPermissions";
import { writeAdminAuditLog } from "../utils/auditLog";

const FOUNDING_TEACHER_KEY = "foundingTeacher";
const MAX_REASON_LENGTH = 500;

export interface FoundingBadgeTarget {
  role?: unknown;
  status?: unknown;
  isDeleted?: unknown;
  deletedAt?: unknown;
}

export function sanitizeBadgeReason(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "invalid-reason", {
      code: "invalid-reason",
    });
  }
  const reason = value.trim();
  if (reason.length > MAX_REASON_LENGTH) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "reason-too-long",
      { code: "reason-too-long", maxLength: MAX_REASON_LENGTH },
    );
  }
  return reason.length === 0 ? null : reason;
}

export function validateFoundingBadgeTarget(
  target: FoundingBadgeTarget,
  enabled: boolean,
): void {
  if (target.role !== "mohaffez") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "target-not-teacher",
      { code: "target-not-teacher" },
    );
  }
  if (
    target.status === "deleted" ||
    target.isDeleted === true ||
    target.deletedAt != null
  ) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "account-deleted",
      { code: "account-deleted" },
    );
  }
  if (enabled && target.status === "suspended") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "account-suspended",
      { code: "account-suspended" },
    );
  }
}

export function isFoundingBadgeEnabled(
  data: FirebaseFirestore.DocumentData,
): boolean {
  return currentFoundingBadge(data).enabled === true;
}

export function foundingBadgeNeedsChange(
  currentEnabled: boolean,
  requestedEnabled: boolean,
): boolean {
  return currentEnabled !== requestedEnabled;
}

function currentFoundingBadge(
  data: FirebaseFirestore.DocumentData,
): Record<string, unknown> {
  const badges =
    data.badges != null && typeof data.badges === "object"
      ? (data.badges as Record<string, unknown>)
      : {};
  const badge = badges[FOUNDING_TEACHER_KEY];
  return badge != null && typeof badge === "object"
    ? { ...(badge as Record<string, unknown>) }
    : {};
}

export const setTeacherFoundingBadge = functions.https.onCall(
  async (data, context) => {
    const access = await requireAdminAccess(context, "manageTeacherBadges");
    const teacherId =
      typeof data?.teacherId === "string" ? data.teacherId.trim() : "";
    const enabled = data?.enabled;
    const reason = sanitizeBadgeReason(data?.reason);

    if (teacherId.length === 0 || typeof enabled !== "boolean") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "invalid-badge-request",
        { code: "invalid-badge-request" },
      );
    }

    const teacherRef = db.collection("users").doc(teacherId);
    const actorRef = db.collection("users").doc(access.uid);

    const result = await db.runTransaction(async (transaction) => {
      const [teacherSnap, actorSnap] = await Promise.all([
        transaction.get(teacherRef),
        transaction.get(actorRef),
      ]);

      if (!teacherSnap.exists) {
        throw new functions.https.HttpsError("not-found", "user-not-found", {
          code: "user-not-found",
        });
      }

      const teacher = teacherSnap.data() ?? {};
      validateFoundingBadgeTarget(teacher, enabled);

      const previousBadge = currentFoundingBadge(teacher);
      const previousEnabled = isFoundingBadgeEnabled(teacher);
      if (!foundingBadgeNeedsChange(previousEnabled, enabled)) {
        return {
          changed: false,
          teacherName:
            String(teacher.name ?? teacher.displayName ?? "").trim() || null,
        };
      }

      const actor = actorSnap.data() ?? {};
      const actorName =
        String(actor.name ?? actor.displayName ?? "").trim() || null;
      const actorEmail =
        String(actor.email ?? context.auth?.token.email ?? "").trim() || null;
      const teacherName =
        String(teacher.name ?? teacher.displayName ?? "").trim() || null;
      const timestamp = FieldValue.serverTimestamp();
      const nextBadge: Record<string, unknown> = {
        ...previousBadge,
        enabled,
        updatedAt: timestamp,
      };

      if (enabled) {
        Object.assign(nextBadge, {
          grantedAt: timestamp,
          grantedBy: access.uid,
          grantedByName: actorName ?? actorEmail ?? "Admin",
          reason,
        });
      } else {
        Object.assign(nextBadge, {
          revokedAt: timestamp,
          revokedBy: access.uid,
          revocationReason: reason,
        });
      }

      transaction.update(teacherRef, {
        [`badges.${FOUNDING_TEACHER_KEY}`]: nextBadge,
        updatedAt: timestamp,
      });

      await writeAdminAuditLog({
        action: enabled
          ? "TEACHER_FOUNDING_BADGE_GRANTED"
          : "TEACHER_FOUNDING_BADGE_REVOKED",
        actorId: access.uid,
        actorName,
        actorEmail,
        actorRole: access.role,
        targetUserId: teacherId,
        targetId: teacherId,
        targetType: "teacher_badge",
        reason,
        source: "adminDashboard",
        before: { enabled: previousEnabled },
        after: { enabled },
        data: {
          badge: FOUNDING_TEACHER_KEY,
          teacherName,
        },
        context,
        transaction,
      });

      return { changed: true, teacherName };
    });

    functions.logger.info("Teacher founding badge updated", {
      actorId: access.uid,
      teacherId,
      enabled,
      changed: result.changed,
    });

    return {
      success: true,
      changed: result.changed,
      teacherId,
      badge: FOUNDING_TEACHER_KEY,
      enabled,
      updatedAt: new Date().toISOString(),
    };
  },
);
