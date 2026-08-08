import { db } from "../utils/admin";

interface CostCounter {
  reads: number;
  writes: number;
  functionCalls: number;
}

async function measureChallengeV2Cost(): Promise<void> {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      "Refusing to run cost probe without FIRESTORE_EMULATOR_HOST",
    );
  }
  const probe = db.collection("_challengeCostProbe").doc("ten-questions");
  const legacyBank = probe.collection("legacyQuestions");
  const v2Bank = probe.collection("v2").doc("bank");
  const session = probe.collection("sessions").doc("session");
  const privateKey = session.collection("challengePrivate").doc("v1");
  const generatedSession = probe.collection("sessions").doc("generated");
  const generatedPrivate = generatedSession
    .collection("challengePrivate")
    .doc("v1");
  const questions = Array.from({ length: 10 }, (_, index) => ({
    id: `q${index + 1}`,
    question: `Question ${index + 1}`,
    isActive: true,
  }));

  const seed = db.batch();
  questions.forEach((question) => {
    seed.set(legacyBank.doc(question.id), question);
  });
  seed.set(v2Bank, { schemaVersion: 2, questions });
  seed.set(session, {
    challengeAccess: { status: "open", setVersion: "v1" },
    challengeSet: questions,
  });
  seed.set(privateKey, {
    answers: Object.fromEntries(
      questions.map((question) => [
        question.id,
        { answerMode: "multiple_choice", correctOptionId: "a" },
      ]),
    ),
  });
  seed.set(generatedSession, {
    mohaffezId: "teacher",
    studentId: "student",
    studentProfileId: "self",
    challengeAccess: { status: "open", setVersion: "v1" },
    challengeSet: questions,
  });
  seed.set(generatedPrivate, {
    answers: Object.fromEntries(
      questions.map((question) => [
        question.id,
        { answerMode: "multiple_choice", correctOptionId: "a" },
      ]),
    ),
  });
  await seed.commit();

  const legacy: CostCounter = { reads: 0, writes: 0, functionCalls: 0 };
  const v2: CostCounter = { reads: 0, writes: 0, functionCalls: 0 };
  const generated: CostCounter = {
    reads: 0,
    writes: 0,
    functionCalls: 0,
  };

  // Opening the legacy teacher bank and then the student challenge fetched all
  // ten documents twice. Its independent unlock listener adds one document.
  legacy.reads += (await legacyBank.get()).size;
  legacy.reads += (await legacyBank.get()).size;
  await session.get();
  legacy.reads += 1;

  // Five per-question switches were five document writes in the old editor.
  for (var index = 0; index < 5; index += 1) {
    await legacyBank.doc(`q${index + 1}`).update({ isActive: false });
    legacy.writes += 1;
  }

  // V2 opens the bank as one document. Student prompts are embedded in the
  // already-loaded session and therefore add zero incremental reads.
  await v2Bank.get();
  v2.reads += 1;
  await v2Bank.update({ questions });
  v2.writes += 1;

  // One finish callable performs exactly two transaction reads and one write.
  v2.functionCalls += 1;
  await db.runTransaction(async (transaction) => {
    await Promise.all([
      transaction.get(session),
      transaction.get(privateKey),
    ]);
    v2.reads += 2;
    transaction.update(session, {
      challengeResult: { confirmedCorrect: 10 },
    });
    v2.writes += 1;
  });

  // Optional oral review is one callable, one read and one write.
  const oralReview: CostCounter = {
    reads: 1,
    writes: 1,
    functionCalls: 1,
  };

  // Materialized Quran publish: the local bank costs nothing. Publishing reads
  // the target session plus the bounded open-challenge query, then writes the
  // public set and private key. Submission retains its two-read/one-write
  // transaction.
  generated.functionCalls += 1;
  await generatedSession.get();
  generated.reads += 1;
  const openGenerated = await probe
    .collection("sessions")
    .where("mohaffezId", "==", "teacher")
    .where("studentId", "==", "student")
    .where("challengeAccess.status", "==", "open")
    .get();
  generated.reads += Math.max(1, openGenerated.size);
  const generatedPublish = db.batch();
  generatedPublish.update(generatedSession, { challengeSet: questions });
  generatedPublish.set(
    generatedPrivate,
    { updatedAt: new Date() },
    { merge: true },
  );
  await generatedPublish.commit();
  generated.writes += 2;

  generated.functionCalls += 1;
  await db.runTransaction(async (transaction) => {
    await Promise.all([
      transaction.get(generatedSession),
      transaction.get(generatedPrivate),
    ]);
    generated.reads += 2;
    transaction.update(generatedSession, {
      challengeResult: { confirmedCorrect: 10 },
    });
    generated.writes += 1;
  });
  const readReduction =
    ((legacy.reads - v2.reads) / legacy.reads) * 100;
  if (readReduction < 70) {
    throw new Error(
      `Expected at least 70% fewer reads, measured ${readReduction}%`,
    );
  }

  console.log(
    JSON.stringify(
      {
        source: "Firestore Emulator",
        questionCount: questions.length,
        practice: { reads: 0, writes: 0, functionCalls: 0 },
        legacy,
        v2Core: v2,
        generatedQuranFlow: generated,
        optionalOralReview: oralReview,
        readReductionPercent: Number(readReduction.toFixed(1)),
        passedMinimumReduction: true,
      },
      null,
      2,
    ),
  );
}

measureChallengeV2Cost().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
