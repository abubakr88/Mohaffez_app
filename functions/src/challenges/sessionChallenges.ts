import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db, FieldValue } from "../utils/admin";
import {
  gradeChallengeResponses,
  materializedChallengeQuestionsError,
  normalizeChallengeAnswerMode,
  normalizeChallengeProfileId,
} from "./sessionChallengePolicy";

const MIN_QUESTIONS = 5;
const MAX_QUESTIONS = 10;
const MAX_BANK_QUESTIONS = 30;
const XP_PER_CORRECT = 10;
const OPEN_FALLBACK_MS = 2 * 60 * 60 * 1000;
const SESSION_GRACE_MS = 30 * 60 * 1000;

type AnswerMode =
  | "multiple_choice"
  | "ordering"
  | "oral"
  | "teacher_review";

interface ChallengeOption {
  id: string;
  text: string;
}

interface BankQuestion {
  id: string;
  type: string;
  answerMode: AnswerMode;
  source?: "teacher_bank" | "quran_generated";
  generatorVersion?: number;
  surahNumber?: number;
  anchorAyah?: number;
  question: string;
  hint?: string;
  difficulty: string;
  options: ChallengeOption[];
  correctOptionId?: string;
  correctOrder: string[];
  answer?: string;
  isActive: boolean;
}

function cleanString(value: unknown, maxLength: number): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLength);
}

function normalizeProfileId(value: unknown): string {
  return normalizeChallengeProfileId(value);
}

function learnerKey(studentId: string, profileId: string): string {
  return `${studentId}__${profileId.replace(/\//g, "_")}`;
}

function normalizeAnswerMode(value: unknown): AnswerMode {
  return normalizeChallengeAnswerMode(value);
}

function parseOptions(value: unknown): ChallengeOption[] {
  if (!Array.isArray(value)) return [];
  return value
    .slice(0, 8)
    .map((raw) => {
      const option = raw as Record<string, unknown>;
      return {
        id: cleanString(option.id, 64),
        text: cleanString(option.text, 500),
      };
    })
    .filter((option) => option.id.length > 0 && option.text.length > 0);
}

function parseBankQuestion(value: unknown): BankQuestion | null {
  if (!value || typeof value !== "object") return null;
  const raw = value as Record<string, unknown>;
  const id = cleanString(raw.id, 128);
  const question = cleanString(raw.question, 1200);
  if (!id || !question) return null;
  return {
    id,
    type: cleanString(raw.type, 64) || "open_question",
    answerMode: normalizeAnswerMode(raw.answerMode),
    source:
      raw.source === "quran_generated"
        ? "quran_generated"
        : "teacher_bank",
    generatorVersion:
      typeof raw.generatorVersion === "number"
        ? Math.trunc(raw.generatorVersion)
        : undefined,
    surahNumber:
      typeof raw.surahNumber === "number"
        ? Math.trunc(raw.surahNumber)
        : undefined,
    anchorAyah:
      typeof raw.anchorAyah === "number"
        ? Math.trunc(raw.anchorAyah)
        : undefined,
    question,
    hint: cleanString(raw.hint, 600) || undefined,
    difficulty: cleanString(raw.difficulty, 16) || "medium",
    options: parseOptions(raw.options),
    correctOptionId:
      cleanString(raw.correctOptionId, 64) || undefined,
    correctOrder: Array.isArray(raw.correctOrder)
      ? raw.correctOrder
          .slice(0, 8)
          .map((item) => cleanString(item, 64))
          .filter(Boolean)
      : [],
    answer: cleanString(raw.answer, 1200) || undefined,
    isActive: raw.isActive !== false,
  };
}

function publicQuestion(question: BankQuestion): Record<string, unknown> {
  const visibleOptions =
    question.answerMode === "ordering"
      ? shuffledOptions(question.options)
      : question.options;
  return {
    id: question.id,
    type: question.type,
    answerMode: question.answerMode,
    ...(question.source ? { source: question.source } : {}),
    ...(question.generatorVersion !== undefined
      ? { generatorVersion: question.generatorVersion }
      : {}),
    ...(question.surahNumber !== undefined
      ? { surahNumber: question.surahNumber }
      : {}),
    ...(question.anchorAyah !== undefined
      ? { anchorAyah: question.anchorAyah }
      : {}),
    question: question.question,
    ...(question.hint ? { hint: question.hint } : {}),
    difficulty: question.difficulty,
    ...(visibleOptions.length > 0 ? { options: visibleOptions } : {}),
  };
}

function shuffledOptions(options: ChallengeOption[]): ChallengeOption[] {
  const shuffled = [...options];
  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    [shuffled[index], shuffled[swapIndex]] = [
      shuffled[swapIndex],
      shuffled[index],
    ];
  }
  return shuffled;
}

function answerKey(question: BankQuestion): Record<string, unknown> {
  return {
    answerMode: question.answerMode,
    ...(question.correctOptionId
      ? { correctOptionId: question.correctOptionId }
      : {}),
    ...(question.correctOrder.length > 0
      ? { correctOrder: question.correctOrder }
      : {}),
    ...(question.answer ? { referenceAnswer: question.answer } : {}),
  };
}

function validatePublishedQuestion(question: BankQuestion): void {
  if (!question.isActive) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "لا يمكن نشر سؤال غير مفعّل",
    );
  }
  if (question.answerMode === "multiple_choice") {
    const optionIds = new Set(question.options.map((option) => option.id));
    if (
      question.options.length < 2 ||
      optionIds.size !== question.options.length ||
      !question.correctOptionId ||
      !question.options.some(
        (option) => option.id === question.correctOptionId,
      )
    ) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `السؤال ${question.id} يحتاج خيارات وإجابة صحيحة`,
      );
    }
  }
  if (question.answerMode === "ordering") {
    const optionIds = new Set(question.options.map((option) => option.id));
    if (
      question.options.length < 3 ||
      optionIds.size !== question.options.length ||
      question.correctOrder.length !== question.options.length ||
      new Set(question.correctOrder).size !== question.options.length ||
      question.correctOrder.some((id) => !optionIds.has(id))
    ) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `السؤال ${question.id} يحتاج ترتيبًا صحيحًا لكل العناصر`,
      );
    }
  }
}

function expiryForSession(
  session: FirebaseFirestore.DocumentData,
  now: Date,
): admin.firestore.Timestamp {
  const slotEnd = session.slotEnd;
  if (slotEnd instanceof admin.firestore.Timestamp) {
    return admin.firestore.Timestamp.fromDate(
      new Date(slotEnd.toDate().getTime() + SESSION_GRACE_MS),
    );
  }
  return admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() + OPEN_FALLBACK_MS),
  );
}

export const publishSessionChallenge = functions.https.onCall(
  async (data, context) => {
    const teacherId = context.auth?.uid;
    if (!teacherId) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }

    const sessionId = cleanString(data?.sessionId, 128);
    const studentId = cleanString(data?.studentId, 128);
    const studentProfileId = normalizeProfileId(data?.studentProfileId);
    const hasMaterializedQuestions = Array.isArray(data?.questions);
    const materializedError = hasMaterializedQuestions
      ? materializedChallengeQuestionsError(
          data.questions,
          MIN_QUESTIONS,
          MAX_QUESTIONS,
        )
      : null;
    if (materializedError) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `بيانات الأسئلة غير صالحة: ${materializedError}`,
      );
    }
    const materializedQuestions = hasMaterializedQuestions
      ? (data.questions as unknown[])
          .map(parseBankQuestion)
          .filter((item): item is BankQuestion => item !== null)
      : [];
    const questionIds: string[] = Array.isArray(data?.questionIds)
      ? data.questionIds
          .map((id: unknown) => cleanString(id, 128))
          .filter((id: string): id is string => id.length > 0)
      : [];
    const uniqueQuestionIds: string[] = [...new Set<string>(questionIds)];

    if (!sessionId || !studentId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بيانات الجلسة والطالب مطلوبة",
      );
    }
    if (
      !hasMaterializedQuestions &&
      (uniqueQuestionIds.length < MIN_QUESTIONS ||
        uniqueQuestionIds.length > MAX_QUESTIONS)
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `اختر من ${MIN_QUESTIONS} إلى ${MAX_QUESTIONS} أسئلة`,
      );
    }

    const sessionRef = db.collection("hafizSessions").doc(sessionId);
    const sessionSnapshot = await sessionRef.get();

    if (!sessionSnapshot.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "الجلسة غير موجودة",
      );
    }
    const session = sessionSnapshot.data()!;
    if (
      session.mohaffezId !== teacherId ||
      session.studentId !== studentId
    ) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "لا يمكنك إدارة تحديات هذه الجلسة",
      );
    }
    if (session.status !== "accepted") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "يمكن نشر التحديات للجلسات المقبولة فقط",
      );
    }
    if (normalizeProfileId(session.studentProfileId) !== studentProfileId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "ملف الطفل لا يطابق الجلسة",
      );
    }
    if (
      cleanString(session.challengeResult?.scoredAttemptId, 128).length > 0
    ) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "تم احتساب محاولة هذه الجلسة ولا يمكن إنشاء محاولة نقاط جديدة",
      );
    }
    let questions: BankQuestion[];
    if (hasMaterializedQuestions) {
      if (materializedQuestions.length !== data.questions.length) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "تعذر قراءة بعض الأسئلة المنشورة",
        );
      }
      questions = materializedQuestions;
    } else {
      const bankRef = db
        .collection("users")
        .doc(teacherId)
        .collection("studentChallengeBanks")
        .doc(learnerKey(studentId, studentProfileId));
      const bankSnapshot = await bankRef.get();
      if (!bankSnapshot.exists) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "احفظ بنك الأسئلة أولًا",
        );
      }
      const rawBank = bankSnapshot.data()?.questions;
      const bank = Array.isArray(rawBank)
        ? rawBank
            .slice(0, MAX_BANK_QUESTIONS)
            .map(parseBankQuestion)
            .filter((item): item is BankQuestion => item !== null)
        : [];
      const byId = new Map(bank.map((question) => [question.id, question]));
      const selected = uniqueQuestionIds.map((id) => byId.get(id));
      if (selected.some((question) => !question)) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "بعض الأسئلة المختارة لم تعد موجودة في البنك",
        );
      }
      questions = selected as BankQuestion[];
    }
    questions.forEach(validatePublishedQuestion);

    const now = new Date();
    const setVersion = `${Date.now()}-${Math.random()
      .toString(36)
      .slice(2, 10)}`;
    const expiresAt = expiryForSession(session, now);
    const privateRef = sessionRef
      .collection("challengePrivate")
      .doc(setVersion);
    const openChallenges = await db
      .collection("hafizSessions")
      .where("mohaffezId", "==", teacherId)
      .where("studentId", "==", studentId)
      .where("challengeAccess.status", "==", "open")
      .limit(50)
      .get();

    const batch = db.batch();
    openChallenges.docs.forEach((document) => {
      const previous = document.data();
      if (
        document.id !== sessionId &&
        normalizeProfileId(previous.studentProfileId) === studentProfileId
      ) {
        batch.update(document.ref, {
          "challengeAccess.status": "closed",
          quizUnlocked: false,
        });
      }
    });
    batch.update(
      sessionRef,
      {
        challengeAccess: {
          status: "open",
          studentProfileId,
          questionCount: questions.length,
          setVersion,
          openedAt: FieldValue.serverTimestamp(),
          expiresAt,
        },
        challengeSet: questions.map(publicQuestion),
        challengeResult: FieldValue.delete(),
        quizUnlocked: true,
      },
      { lastUpdateTime: sessionSnapshot.updateTime! },
    );
    batch.set(privateRef, {
      teacherId,
      studentId,
      studentProfileId,
      setVersion,
      answers: Object.fromEntries(
        questions.map((question) => [question.id, answerKey(question)]),
      ),
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return {
      success: true,
      sessionId,
      setVersion,
      questionCount: questions.length,
      expiresAt: expiresAt.toDate().toISOString(),
    };
  },
);

export const submitSessionChallenge = functions.https.onCall(
  async (data, context) => {
    const studentId = context.auth?.uid;
    if (!studentId) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }
    const sessionId = cleanString(data?.sessionId, 128);
    const setVersion = cleanString(data?.setVersion, 128);
    const clientAttemptId = cleanString(data?.clientAttemptId, 128);
    const studentProfileId = normalizeProfileId(data?.studentProfileId);
    const rawResponses = Array.isArray(data?.responses)
      ? data.responses.slice(0, MAX_QUESTIONS)
      : [];
    if (!sessionId || !setVersion || !clientAttemptId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بيانات المحاولة غير مكتملة",
      );
    }

    const sessionRef = db.collection("hafizSessions").doc(sessionId);
    const privateRef = sessionRef
      .collection("challengePrivate")
      .doc(setVersion);

    return db.runTransaction(async (transaction) => {
      const [sessionSnapshot, privateSnapshot] = await Promise.all([
        transaction.get(sessionRef),
        transaction.get(privateRef),
      ]);
      if (!sessionSnapshot.exists || !privateSnapshot.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "تحدي الجلسة غير موجود",
        );
      }
      const session = sessionSnapshot.data()!;
      if (session.studentId !== studentId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "هذه المحاولة لا تخص حسابك",
        );
      }
      if (
        normalizeProfileId(session.studentProfileId) !== studentProfileId
      ) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "التحدي لا يخص ملف الطفل النشط",
        );
      }
      const access = session.challengeAccess as
        | Record<string, unknown>
        | undefined;
      const priorResult = session.challengeResult as
        | Record<string, unknown>
        | undefined;
      const priorAttemptId = cleanString(
        priorResult?.scoredAttemptId,
        128,
      );
      if (priorAttemptId) {
        if (
          priorAttemptId === clientAttemptId &&
          cleanString(priorResult?.setVersion, 128) === setVersion
        ) {
          const priorPending = Array.isArray(
            priorResult?.pendingQuestionIds,
          )
            ? priorResult.pendingQuestionIds.length
            : 0;
          return {
            success: true,
            idempotent: true,
            correct:
              typeof priorResult?.confirmedCorrect === "number"
                ? priorResult.confirmedCorrect
                : 0,
            asked:
              typeof priorResult?.objectiveAsked === "number"
                ? priorResult.objectiveAsked
                : 0,
            bestStreak:
              typeof priorResult?.bestStreak === "number"
                ? priorResult.bestStreak
                : 0,
            accuracyPct:
              typeof priorResult?.accuracyPct === "number"
                ? priorResult.accuracyPct
                : 0,
            confirmedPoints:
              typeof priorResult?.confirmedPoints === "number"
                ? priorResult.confirmedPoints
                : 0,
            pendingReviewCount: priorPending,
          };
        }
        throw new functions.https.HttpsError(
          "already-exists",
          "تم احتساب محاولة سابقة لهذه الجلسة",
        );
      }
      if (
        !access ||
        access.status !== "open" ||
        access.setVersion !== setVersion ||
        normalizeProfileId(access.studentProfileId) !== studentProfileId
      ) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "التحدي غير مفتوح",
        );
      }
      const expiresAt = access.expiresAt;
      if (
        expiresAt instanceof admin.firestore.Timestamp &&
        expiresAt.toMillis() < Date.now()
      ) {
        throw new functions.https.HttpsError(
          "deadline-exceeded",
          "انتهى وقت التحدي",
        );
      }

      const privateData = privateSnapshot.data()!;
      if (
        privateData.teacherId !== session.mohaffezId ||
        privateData.studentId !== studentId ||
        normalizeProfileId(privateData.studentProfileId) !==
          studentProfileId ||
        privateData.setVersion !== setVersion
      ) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "مفتاح الإجابات لا يطابق هذه المحاولة",
        );
      }

      const publicQuestions = Array.isArray(session.challengeSet)
        ? session.challengeSet.slice(0, MAX_QUESTIONS)
        : [];
      const answerKeys =
        (privateData.answers as Record<
          string,
          Record<string, unknown>
        > | undefined) ?? {};
      const grade = gradeChallengeResponses(
        publicQuestions,
        answerKeys,
        rawResponses,
      );
      const correct = grade.confirmedCorrect;
      const objectiveAsked = grade.objectiveAsked;
      const bestStreak = grade.bestStreak;
      const pendingQuestionIds = grade.pendingQuestionIds;

      const accuracyPct =
        objectiveAsked === 0
          ? 0
          : Math.round((correct / objectiveAsked) * 100);
      const result = {
        scoredAttemptId: clientAttemptId,
        setVersion,
        confirmedCorrect: correct,
        objectiveAsked,
        totalQuestions: publicQuestions.length,
        bestStreak,
        accuracyPct,
        confirmedPoints: correct * XP_PER_CORRECT,
        pendingReview: pendingQuestionIds.length > 0,
        pendingQuestionIds,
        responses: grade.storedResponses,
        responseResults: grade.responseResults,
        submittedAt: FieldValue.serverTimestamp(),
      };
      transaction.update(sessionRef, {
        challengeResult: result,
        "challengeAccess.status": "completed",
        quizUnlocked: false,
        quizCorrect: correct,
        quizAsked: objectiveAsked,
        quizBestStreak: bestStreak,
        quizAccuracyPct: accuracyPct,
      });
      return {
        success: true,
        correct,
        asked: objectiveAsked,
        bestStreak,
        accuracyPct,
        confirmedPoints: correct * XP_PER_CORRECT,
        pendingReviewCount: pendingQuestionIds.length,
      };
    });
  },
);

export const reviewSessionChallenge = functions.https.onCall(
  async (data, context) => {
    const teacherId = context.auth?.uid;
    if (!teacherId) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }
    const sessionId = cleanString(data?.sessionId, 128);
    const rawVerdicts =
      data?.verdicts && typeof data.verdicts === "object"
        ? (data.verdicts as Record<string, unknown>)
        : {};
    if (!sessionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "رقم الجلسة مطلوب",
      );
    }

    const sessionRef = db.collection("hafizSessions").doc(sessionId);
    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(sessionRef);
      if (!snapshot.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "الجلسة غير موجودة",
        );
      }
      const session = snapshot.data()!;
      if (session.mohaffezId !== teacherId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "لا يمكنك مراجعة هذه الجلسة",
        );
      }
      const result = session.challengeResult as
        | Record<string, unknown>
        | undefined;
      const pendingIds = Array.isArray(result?.pendingQuestionIds)
        ? result!.pendingQuestionIds
            .map((id) => cleanString(id, 128))
            .filter(Boolean)
        : [];
      if (pendingIds.length === 0) {
        return { success: true, idempotent: true, pendingReviewCount: 0 };
      }
      if (
        pendingIds.some(
          (questionId) => typeof rawVerdicts[questionId] !== "boolean",
        )
      ) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "يجب مراجعة جميع الإجابات المعلقة دفعة واحدة",
        );
      }

      const approved = pendingIds.filter(
        (questionId) => rawVerdicts[questionId] === true,
      ).length;
      const previousCorrect =
        typeof result?.confirmedCorrect === "number"
          ? result.confirmedCorrect
          : 0;
      const previousAsked =
        typeof result?.objectiveAsked === "number"
          ? result.objectiveAsked
          : 0;
      const correct = previousCorrect + approved;
      const asked = previousAsked + pendingIds.length;
      const accuracyPct =
        asked === 0 ? 0 : Math.round((correct / asked) * 100);
      const confirmedPoints = correct * XP_PER_CORRECT;
      const verdicts = Object.fromEntries(
        pendingIds.map((questionId) => [
          questionId,
          rawVerdicts[questionId] === true,
        ]),
      );

      transaction.update(sessionRef, {
        "challengeResult.confirmedCorrect": correct,
        "challengeResult.totalAsked": asked,
        "challengeResult.accuracyPct": accuracyPct,
        "challengeResult.confirmedPoints": confirmedPoints,
        "challengeResult.pendingReview": false,
        "challengeResult.pendingQuestionIds": [],
        "challengeResult.reviewVerdicts": verdicts,
        "challengeResult.reviewedAt": FieldValue.serverTimestamp(),
        "challengeResult.reviewedBy": teacherId,
        quizCorrect: correct,
        quizAsked: asked,
        quizAccuracyPct: accuracyPct,
      });
      return {
        success: true,
        correct,
        asked,
        accuracyPct,
        confirmedPoints,
        pendingReviewCount: 0,
      };
    });
  },
);
