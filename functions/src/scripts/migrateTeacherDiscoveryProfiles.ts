import { db, FieldValue } from "../utils/admin";

const commit = process.argv.includes("--commit");

export function legacyTeachingServices(value: unknown): Record<string, boolean> {
  const text = typeof value === "string" ? value.trim().toLowerCase() : "";
  if (!text) return {};
  return {
    ...(text.includes("حفظ") || text.includes("تحفيظ")
      ? { memorization: true }
      : {}),
    ...(text.includes("مراجعة") ? { review: true } : {}),
    ...(text.includes("تأسيس") || text.includes("تقوية")
      ? { foundation: true }
      : {}),
    ...(text.includes("تجويد") ? { tajweed: true } : {}),
    ...(text.includes("تصحيح") ? { recitation_correction: true } : {}),
    ...(text.includes("إجاز") || text.includes("اجاز")
      ? { ijazah: true }
      : {}),
    ...(text.includes("قراءات") || text.includes("قراءة عشر")
      ? { qiraat: true }
      : {}),
  };
}

async function migrateTeacherDiscoveryProfiles(): Promise<void> {
  const teachers = await db
    .collection("users")
    .where("role", "==", "mohaffez")
    .get();

  let eligible = 0;
  let skippedStructured = 0;
  let audienceV1NeedsReview = 0;
  let audienceV2Confirmed = 0;
  let audienceMissing = 0;
  let batch = db.batch();
  let pendingWrites = 0;

  for (const teacher of teachers.docs) {
    const data = teacher.data();
    if (data.discoveryProfileVersion === 2 &&
        data.learnerAudiences &&
        typeof data.learnerAudiences === "object") {
      audienceV2Confirmed += 1;
    } else if (data.discoveryProfileVersion === 1 ||
        (data.learnerAgeGroups && data.learnerGenders)) {
      audienceV1NeedsReview += 1;
    } else {
      audienceMissing += 1;
    }
    const existing = data.teachingServices;
    if (existing && typeof existing === "object" &&
        Object.values(existing).some((value) => value === true)) {
      skippedStructured += 1;
      continue;
    }

    const teachingServices = legacyTeachingServices(data.specialization);
    if (Object.keys(teachingServices).length === 0) continue;
    eligible += 1;

    if (commit) {
      batch.update(teacher.ref, {
        teachingServices,
        discoveryMigrationVersion: 1,
        discoveryMigratedAt: FieldValue.serverTimestamp(),
      });
      pendingWrites += 1;
      if (pendingWrites === 400) {
        await batch.commit();
        batch = db.batch();
        pendingWrites = 0;
      }
    }
  }

  if (commit && pendingWrites > 0) await batch.commit();
  console.log(JSON.stringify({
    mode: commit ? "commit" : "dry-run",
    teachers: teachers.size,
    eligible,
    skippedStructured,
    audienceV1NeedsReview,
    audienceV2Confirmed,
    audienceMissing,
  }, null, 2));
}

if (require.main === module) {
  migrateTeacherDiscoveryProfiles().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
