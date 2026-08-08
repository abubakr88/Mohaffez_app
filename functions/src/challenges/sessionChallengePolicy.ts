export type ChallengeAnswerMode =
  | "multiple_choice"
  | "ordering"
  | "oral"
  | "teacher_review";

export interface ChallengeGrade {
  confirmedCorrect: number;
  objectiveAsked: number;
  bestStreak: number;
  pendingQuestionIds: string[];
  storedResponses: Record<string, unknown>;
  responseResults: Record<string, boolean>;
}

const MATERIALIZED_TYPES = new Set([
  "complete_ayah",
  "name_surah",
  "tajweed_rule",
  "order_ayahs",
  "word_meaning",
  "open_question",
]);

// Generated questions are materialized in the publish payload, so the server
// still validates their Quran location and supported interaction mode. Keep
// explicit compatibility with already-published v1 questions while accepting
// the page-aware v2 generator used by the current clients.
const SUPPORTED_QURAN_GENERATOR_VERSIONS = new Set([1, 2]);

function boundedText(
  value: unknown,
  maxLength: number,
  required = false,
): boolean {
  if (value === undefined || value === null) return !required;
  if (typeof value !== "string") return false;
  const length = value.trim().length;
  return required
    ? length > 0 && length <= maxLength
    : length <= maxLength;
}

function integerInRange(
  value: unknown,
  minimum: number,
  maximum: number,
): boolean {
  return (
    typeof value === "number" &&
    Number.isInteger(value) &&
    value >= minimum &&
    value <= maximum
  );
}

export function materializedChallengeQuestionsError(
  value: unknown,
  minimumQuestions = 5,
  maximumQuestions = 10,
): string | null {
  if (
    !Array.isArray(value) ||
    value.length < minimumQuestions ||
    value.length > maximumQuestions
  ) {
    return `questions must contain ${minimumQuestions}-${maximumQuestions} items`;
  }

  const questionIds = new Set<string>();
  for (const raw of value) {
    if (!raw || typeof raw !== "object") return "question must be an object";
    const question = raw as Record<string, unknown>;
    if (!boundedText(question.id, 128, true)) {
      return "question id is invalid";
    }
    const id = (question.id as string).trim();
    if (questionIds.has(id)) return "question ids must be unique";
    questionIds.add(id);

    if (
      !boundedText(question.question, 1200, true) ||
      !boundedText(question.hint, 600) ||
      !boundedText(question.answer, 1200) ||
      !boundedText(question.correctOptionId, 64)
    ) {
      return `question ${id} contains oversized text`;
    }
    if (
      typeof question.type !== "string" ||
      !MATERIALIZED_TYPES.has(question.type)
    ) {
      return `question ${id} has an unsupported type`;
    }
    const mode = question.answerMode;
    if (
      mode !== "multiple_choice" &&
      mode !== "ordering" &&
      mode !== "oral" &&
      mode !== "teacher_review"
    ) {
      return `question ${id} has an unsupported answer mode`;
    }
    if (
      question.difficulty !== "easy" &&
      question.difficulty !== "medium" &&
      question.difficulty !== "hard"
    ) {
      return `question ${id} has an invalid difficulty`;
    }
    if (question.isActive === false) {
      return `question ${id} is not active`;
    }

    const source =
      question.source === undefined ? "teacher_bank" : question.source;
    if (source !== "teacher_bank" && source !== "quran_generated") {
      return `question ${id} has an invalid source`;
    }
    if (source === "quran_generated") {
      if (
        !SUPPORTED_QURAN_GENERATOR_VERSIONS.has(
          question.generatorVersion as number,
        ) ||
        !integerInRange(question.surahNumber, 1, 114) ||
        !integerInRange(question.anchorAyah, 1, 1000)
      ) {
        return `question ${id} has invalid Quran metadata`;
      }
      const expectedMode =
        question.type === "order_ayahs" ? "ordering" : "multiple_choice";
      if (
        (question.type !== "name_surah" &&
          question.type !== "complete_ayah" &&
          question.type !== "order_ayahs") ||
        mode !== expectedMode
      ) {
        return `question ${id} is not a supported generated question`;
      }
    }

    const rawOptions =
      question.options === undefined ? [] : question.options;
    if (!Array.isArray(rawOptions) || rawOptions.length > 8) {
      return `question ${id} has invalid options`;
    }
    const optionIds = new Set<string>();
    for (const rawOption of rawOptions) {
      if (!rawOption || typeof rawOption !== "object") {
        return `question ${id} has an invalid option`;
      }
      const option = rawOption as Record<string, unknown>;
      if (
        !boundedText(option.id, 64, true) ||
        !boundedText(option.text, 500, true)
      ) {
        return `question ${id} has an invalid option`;
      }
      const optionId = (option.id as string).trim();
      if (optionIds.has(optionId)) {
        return `question ${id} has duplicate option ids`;
      }
      optionIds.add(optionId);
    }

    if (mode === "multiple_choice") {
      if (
        rawOptions.length < 2 ||
        typeof question.correctOptionId !== "string" ||
        !optionIds.has(question.correctOptionId.trim())
      ) {
        return `question ${id} has an invalid correct option`;
      }
    } else if (mode === "ordering") {
      const order = question.correctOrder;
      if (
        rawOptions.length < 3 ||
        !Array.isArray(order) ||
        order.length !== rawOptions.length ||
        order.some((item) => typeof item !== "string") ||
        new Set(order).size !== order.length ||
        order.some((item) => !optionIds.has(item))
      ) {
        return `question ${id} has an invalid correct order`;
      }
    }
  }
  return null;
}

export function cleanChallengeString(
  value: unknown,
  maxLength: number,
): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLength);
}

export function normalizeChallengeProfileId(value: unknown): string {
  const text = cleanChallengeString(value, 128);
  return !text || text === "self" ? "self" : text;
}

export function normalizeChallengeAnswerMode(
  value: unknown,
): ChallengeAnswerMode {
  switch (value) {
    case "multiple_choice":
    case "ordering":
    case "oral":
    case "teacher_review":
      return value;
    default:
      return "teacher_review";
  }
}

function sanitizedAnswer(mode: ChallengeAnswerMode, value: unknown): unknown {
  if (mode === "ordering") {
    return Array.isArray(value)
      ? value
          .slice(0, 8)
          .map((item) => cleanChallengeString(item, 64))
      : [];
  }
  if (mode === "multiple_choice") {
    return cleanChallengeString(value, 64);
  }
  return cleanChallengeString(value, 1200);
}

export function gradeChallengeResponses(
  publicQuestions: unknown[],
  answerKeys: Record<string, Record<string, unknown>>,
  rawResponses: unknown[],
): ChallengeGrade {
  const responseMap = new Map<string, unknown>();
  rawResponses.slice(0, 10).forEach((raw) => {
    if (!raw || typeof raw !== "object") return;
    const response = raw as Record<string, unknown>;
    const questionId = cleanChallengeString(response.questionId, 128);
    if (questionId && !responseMap.has(questionId)) {
      responseMap.set(questionId, response.answer);
    }
  });

  let confirmedCorrect = 0;
  let objectiveAsked = 0;
  let streak = 0;
  let bestStreak = 0;
  const pendingQuestionIds: string[] = [];
  const storedResponses: Record<string, unknown> = {};
  const responseResults: Record<string, boolean> = {};

  publicQuestions.slice(0, 10).forEach((rawQuestion) => {
    if (!rawQuestion || typeof rawQuestion !== "object") return;
    const question = rawQuestion as Record<string, unknown>;
    const questionId = cleanChallengeString(question.id, 128);
    const key = answerKeys[questionId];
    if (!questionId || !key) return;

    const mode = normalizeChallengeAnswerMode(key.answerMode);
    const answer = sanitizedAnswer(mode, responseMap.get(questionId));
    storedResponses[questionId] = answer;

    if (mode === "oral" || mode === "teacher_review") {
      pendingQuestionIds.push(questionId);
      return;
    }

    objectiveAsked += 1;
    let isCorrect = false;
    if (mode === "multiple_choice") {
      isCorrect =
        answer === cleanChallengeString(key.correctOptionId, 64);
    } else {
      const submitted = answer as string[];
      const expected = Array.isArray(key.correctOrder)
        ? key.correctOrder.map((item) => cleanChallengeString(item, 64))
        : [];
      isCorrect =
        submitted.length === expected.length &&
        submitted.every((item, index) => item === expected[index]);
    }
    responseResults[questionId] = isCorrect;
    if (isCorrect) {
      confirmedCorrect += 1;
      streak += 1;
      bestStreak = Math.max(bestStreak, streak);
    } else {
      streak = 0;
    }
  });

  return {
    confirmedCorrect,
    objectiveAsked,
    bestStreak,
    pendingQuestionIds,
    storedResponses,
    responseResults,
  };
}
