import * as functions from "firebase-functions";
import { db, FieldValue } from "../utils/admin";
import { requireAdminAccess } from "../utils/adminPermissions";

const MAX_SEARCH_TEXT_LENGTH = 12000;
const MAX_KEYWORDS = 250;

export const onTeacherPricingPlanChanged = functions.firestore
  .document("users/{teacherId}/pricingPlans/{planId}")
  .onWrite(async (_change, context) => {
    const teacherId = String(context.params.teacherId ?? "").trim();
    if (teacherId.length === 0) return;

    await rebuildTeacherPricingSearchTextForTeacher(teacherId);
  });

export const rebuildTeacherPricingSearchText = functions.https.onCall(
  async (data, context) => {
    const teacherId =
      typeof data?.teacherId === "string" ? data.teacherId.trim() : "";
    const rebuildAll = data?.all === true;

    if (rebuildAll) {
      await requireAdminAccess(context, "runMaintenance");
      const teachersSnap = await db
        .collection("users")
        .where("role", "==", "mohaffez")
        .get();

      let updated = 0;
      const teacherIds = teachersSnap.docs.map((doc) => doc.id);
      for (let i = 0; i < teacherIds.length; i += 20) {
        const chunk = teacherIds.slice(i, i + 20);
        await Promise.all(
          chunk.map(async (id) => {
            await rebuildTeacherPricingSearchTextForTeacher(id);
            updated += 1;
          }),
        );
      }

      return { success: true, updated };
    }

    const callerUid = context.auth?.uid;
    if (!callerUid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }

    const targetTeacherId = teacherId.length > 0 ? teacherId : callerUid;
    if (targetTeacherId !== callerUid) {
      await requireAdminAccess(context, "runMaintenance");
    }

    await rebuildTeacherPricingSearchTextForTeacher(targetTeacherId);
    return { success: true, updated: 1, teacherId: targetTeacherId };
  },
);

export async function rebuildTeacherPricingSearchTextForTeacher(
  teacherId: string,
): Promise<void> {
  const teacherRef = db.collection("users").doc(teacherId);
  const [teacherSnap, plansSnap] = await Promise.all([
    teacherRef.get(),
    teacherRef
      .collection("pricingPlans")
      .where("isActive", "==", true)
      .get(),
  ]);

  if (!teacherSnap.exists) return;

  const teacherData = teacherSnap.data() ?? {};
  if (teacherData.role !== "mohaffez") return;

  const pricingSearchText = plansSnap.docs
    .map((doc) => pricingPlanSearchText(doc.data()))
    .join(" ")
    .slice(0, MAX_SEARCH_TEXT_LENGTH);

  await teacherRef.update({
    pricingSearchText,
    pricingSearchKeywords: searchKeywords(pricingSearchText),
    pricingSearchUpdatedAt: FieldValue.serverTimestamp(),
  });
}

function pricingPlanSearchText(data: FirebaseFirestore.DocumentData): string {
  const type = lower(data.type);
  const mode = lower(data.mode);
  const sessionsCount = numberValue(data.sessionsCount);
  const durationMinutes = numberValue(data.sessionDurationMinutes);

  return compactJoin([
    data.title,
    data.description,
    data.countryName,
    data.countryCode,
    data.currencyCode,
    data.currencyLabel,
    planTypeAliases(type),
    sessionModeAliases(mode),
    sessionsCount != null && sessionsCount > 1
      ? `باقة ${sessionsCount} جلسات ${sessionsCount}`
      : null,
    durationMinutes != null && durationMinutes > 0
      ? `${durationMinutes} دقيقة مدة الحلقة مدة الجلسة`
      : null,
  ]);
}

function planTypeAliases(type: string | null): string {
  switch (type) {
    case "bundle":
      return "باقة باقه باقات حزمة جلسات اشتراك bundle package";
    case "single":
      return "جلسة واحدة حصة واحدة حلقة واحدة single";
    default:
      return "";
  }
}

function sessionModeAliases(mode: string | null): string {
  switch (mode) {
    case "online":
      return "أونلاين اونلاين عن بعد عبر الانترنت مكالمة هاتفية هاتف google meet zoom online";
    case "home":
      return "حضوري منزلي في المنزل بيت home offline";
    case "mosque":
      return "حضوري مسجد mosque offline";
    default:
      return "";
  }
}

function searchKeywords(value: string): string[] {
  return Array.from(new Set(normalizeSearchText(value).split(" ")))
    .filter((term) => term.length > 0)
    .slice(0, MAX_KEYWORDS);
}

function normalizeSearchText(value: string): string {
  return value
    .toLowerCase()
    .replace(/[\u064B-\u065F\u0670]/g, "")
    .replace(/ـ/g, "")
    .replace(/[أإآ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ؤ/g, "و")
    .replace(/ئ/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[^\w\u0600-\u06FF]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function compactJoin(values: unknown[]): string {
  return values
    .map((value) => (value == null ? "" : String(value).trim()))
    .filter((value) => value.length > 0)
    .join(" ");
}

function lower(value: unknown): string | null {
  if (value == null) return null;
  const text = String(value).trim().toLowerCase();
  return text.length === 0 ? null : text;
}

function numberValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return null;
}
