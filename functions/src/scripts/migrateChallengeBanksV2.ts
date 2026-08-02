import { db, FieldValue } from "../utils/admin";

interface LegacyQuestion {
  id: string;
  data: FirebaseFirestore.DocumentData;
}

interface LegacyGroup {
  teacherId: string;
  studentId: string;
  questions: LegacyQuestion[];
}

const MAX_BANK_QUESTIONS = 30;
const commit = process.argv.includes("--commit");

function bankKey(studentId: string, profileId: string): string {
  return `${studentId}__${profileId.replace(/\//g, "_")}`;
}

function isLegacyQuestionPath(path: string): boolean {
  const parts = path.split("/");
  return (
    parts.length === 6 &&
    parts[0] === "users" &&
    parts[2] === "studentChallenges" &&
    parts[4] === "questions"
  );
}

async function migrateChallengeBanksV2(): Promise<void> {
  const snapshot = await db.collectionGroup("questions").get();
  const groups = new Map<string, LegacyGroup>();

  snapshot.docs.forEach((document) => {
    if (!isLegacyQuestionPath(document.ref.path)) return;
    const parts = document.ref.path.split("/");
    const teacherId = parts[1];
    const studentId = parts[3];
    const key = `${teacherId}/${studentId}`;
    const group = groups.get(key) ?? {
      teacherId,
      studentId,
      questions: [],
    };
    group.questions.push({ id: document.id, data: document.data() });
    groups.set(key, group);
  });

  let migratedBanks = 0;
  let migratedQuestions = 0;
  let overflowQuestions = 0;
  let parentBanks = 0;
  let skippedExistingBanks = 0;
  let batch = db.batch();
  let batchWrites = 0;

  for (const group of groups.values()) {
    const studentSnapshot = await db
      .collection("users")
      .doc(group.studentId)
      .get();
    const role = studentSnapshot.data()?.role;
    const isParent = role === "parent";
    const profileId = isParent ? "legacy_unassigned" : "self";
    const questions = group.questions
      .sort((a, b) => {
        const aCreated = a.data.createdAt;
        const bCreated = b.data.createdAt;
        const aMs =
          aCreated && typeof aCreated.toMillis === "function"
            ? aCreated.toMillis()
            : 0;
        const bMs =
          bCreated && typeof bCreated.toMillis === "function"
            ? bCreated.toMillis()
            : 0;
        return aMs - bMs;
      })
      .slice(0, MAX_BANK_QUESTIONS)
      .map((question) => ({
        id: question.id,
        type:
          typeof question.data.type === "string"
            ? question.data.type
            : "open_question",
        answerMode:
          typeof question.data.answerMode === "string"
            ? question.data.answerMode
            : "teacher_review",
        question:
          typeof question.data.question === "string"
            ? question.data.question.trim().slice(0, 1200)
            : "",
        hint:
          typeof question.data.hint === "string"
            ? question.data.hint.trim().slice(0, 600)
            : "",
        answer:
          typeof question.data.answer === "string"
            ? question.data.answer.trim().slice(0, 1200)
            : "",
        difficulty:
          typeof question.data.difficulty === "string"
            ? question.data.difficulty
            : "medium",
        isActive: question.data.isActive !== false,
        createdAt: question.data.createdAt ?? new Date(),
      }))
      .filter((question) => question.question.trim().length > 0);

    const overflow = Math.max(0, group.questions.length - questions.length);
    const learnerKey = bankKey(group.studentId, profileId);
    const target = db
      .collection("users")
      .doc(group.teacherId)
      .collection("studentChallengeBanks")
      .doc(learnerKey);
    if ((await target.get()).exists) {
      skippedExistingBanks += 1;
      continue;
    }

    if (commit) {
      batch.set(
        target,
        {
          studentId: group.studentId,
          studentProfileId: profileId,
          learnerKey,
          schemaVersion: 2,
          templates: [],
          questionOrder: questions.map((question) => question.id),
          questions,
          legacyUnassigned: isParent,
          legacySourceCount: group.questions.length,
          legacyOverflowCount: overflow,
          migratedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      batchWrites += 1;
      if (batchWrites === 400) {
        await batch.commit();
        batch = db.batch();
        batchWrites = 0;
      }
    }

    migratedBanks += 1;
    migratedQuestions += questions.length;
    overflowQuestions += overflow;
    if (isParent) parentBanks += 1;
  }

  if (commit && batchWrites > 0) {
    await batch.commit();
  }

  console.log(
    JSON.stringify(
      {
        mode: commit ? "commit" : "dry-run",
        legacyDocuments: snapshot.size,
        migratedBanks,
        migratedQuestions,
        overflowQuestions,
        parentBanksMovedToLegacyUnassigned: parentBanks,
        skippedExistingBanks,
        legacyDocumentsDeleted: 0,
      },
      null,
      2,
    ),
  );
}

migrateChallengeBanksV2().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
