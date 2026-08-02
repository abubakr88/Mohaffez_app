import { describe, expect, it } from "vitest";
import {
  gradeChallengeResponses,
  materializedChallengeQuestionsError,
  normalizeChallengeProfileId,
} from "../sessionChallengePolicy";

describe("session challenge policy", () => {
  it("normalizes self and child profiles without mixing them", () => {
    expect(normalizeChallengeProfileId(undefined)).toBe("self");
    expect(normalizeChallengeProfileId("")).toBe("self");
    expect(normalizeChallengeProfileId("self")).toBe("self");
    expect(normalizeChallengeProfileId(" child-a ")).toBe("child-a");
    expect(normalizeChallengeProfileId("child-a")).not.toBe(
      normalizeChallengeProfileId("child-b"),
    );
  });

  it("grades objective answers and leaves oral answers pending", () => {
    const grade = gradeChallengeResponses(
      [
        { id: "mcq" },
        { id: "order" },
        { id: "oral" },
      ],
      {
        mcq: {
          answerMode: "multiple_choice",
          correctOptionId: "b",
        },
        order: {
          answerMode: "ordering",
          correctOrder: ["1", "2", "3"],
        },
        oral: { answerMode: "oral" },
      },
      [
        { questionId: "mcq", answer: "b" },
        { questionId: "order", answer: ["1", "2", "3"] },
        { questionId: "oral", answer: "تمت الإجابة شفهيًا" },
      ],
    );

    expect(grade.confirmedCorrect).toBe(2);
    expect(grade.objectiveAsked).toBe(2);
    expect(grade.bestStreak).toBe(2);
    expect(grade.pendingQuestionIds).toEqual(["oral"]);
    expect(grade.responseResults).toEqual({ mcq: true, order: true });
  });

  it("does not accept duplicated responses or a wrong ordering", () => {
    const grade = gradeChallengeResponses(
      [{ id: "order" }],
      {
        order: {
          answerMode: "ordering",
          correctOrder: ["1", "2", "3"],
        },
      },
      [
        { questionId: "order", answer: ["3", "2", "1"] },
        { questionId: "order", answer: ["1", "2", "3"] },
      ],
    );

    expect(grade.confirmedCorrect).toBe(0);
    expect(grade.objectiveAsked).toBe(1);
    expect(grade.storedResponses.order).toEqual(["3", "2", "1"]);
  });

  it("bounds stored open responses before writing the session", () => {
    const grade = gradeChallengeResponses(
      [{ id: "open" }],
      { open: { answerMode: "teacher_review" } },
      [{ questionId: "open", answer: "x".repeat(5000) }],
    );

    expect((grade.storedResponses.open as string).length).toBe(1200);
    expect(grade.pendingQuestionIds).toEqual(["open"]);
  });

  it("accepts a mixed materialized publish payload", () => {
    const questions = [
      {
        id: "qv1-s1-name-a1",
        type: "name_surah",
        answerMode: "multiple_choice",
        source: "quran_generated",
        generatorVersion: 1,
        surahNumber: 1,
        anchorAyah: 1,
        question: "من أي سورة؟",
        difficulty: "easy",
        isActive: true,
        options: [
          { id: "a", text: "الفاتحة" },
          { id: "b", text: "البقرة" },
        ],
        correctOptionId: "a",
        correctOrder: [],
      },
      {
        id: "custom-1",
        type: "open_question",
        answerMode: "teacher_review",
        source: "teacher_bank",
        question: "سؤال خاص",
        difficulty: "medium",
        isActive: true,
        options: [],
        correctOrder: [],
      },
      {
        id: "custom-2",
        type: "open_question",
        answerMode: "oral",
        source: "teacher_bank",
        question: "سؤال شفهي",
        difficulty: "medium",
        isActive: true,
        options: [],
        correctOrder: [],
      },
      {
        id: "custom-3",
        type: "word_meaning",
        answerMode: "teacher_review",
        source: "teacher_bank",
        question: "ما معنى الكلمة؟",
        difficulty: "medium",
        isActive: true,
        options: [],
        correctOrder: [],
      },
      {
        id: "custom-4",
        type: "tajweed_rule",
        answerMode: "teacher_review",
        source: "teacher_bank",
        question: "ما الحكم؟",
        difficulty: "hard",
        isActive: true,
        options: [],
        correctOrder: [],
      },
    ];

    expect(materializedChallengeQuestionsError(questions)).toBeNull();
  });

  it("rejects duplicate IDs, leaked oversized text, and bad answer keys", () => {
    const validQuestion = {
      id: "q1",
      type: "name_surah",
      answerMode: "multiple_choice",
      source: "teacher_bank",
      question: "من أي سورة؟",
      difficulty: "easy",
      isActive: true,
      options: [
        { id: "a", text: "الفاتحة" },
        { id: "b", text: "البقرة" },
      ],
      correctOptionId: "a",
      correctOrder: [],
    };
    const base = Array.from({ length: 5 }, (_, index) => ({
      ...validQuestion,
      id: `q${index}`,
    }));

    expect(
      materializedChallengeQuestionsError([
        ...base.slice(0, 4),
        { ...validQuestion, id: "q0" },
      ]),
    ).toContain("unique");
    expect(
      materializedChallengeQuestionsError([
        ...base.slice(0, 4),
        { ...validQuestion, id: "last", question: "x".repeat(1201) },
      ]),
    ).toContain("oversized");
    expect(
      materializedChallengeQuestionsError([
        ...base.slice(0, 4),
        { ...validQuestion, id: "last", correctOptionId: "missing" },
      ]),
    ).toContain("correct option");
  });

  it("requires generated Quran metadata and supported objective modes", () => {
    const generated = Array.from({ length: 5 }, (_, index) => ({
      id: `qv1-s1-name-a${index + 1}`,
      type: "name_surah",
      answerMode: "multiple_choice",
      source: "quran_generated",
      generatorVersion: 1,
      surahNumber: 1,
      anchorAyah: index + 1,
      question: "من أي سورة؟",
      difficulty: "easy",
      isActive: true,
      options: [
        { id: "a", text: "الفاتحة" },
        { id: "b", text: "البقرة" },
      ],
      correctOptionId: "a",
      correctOrder: [],
    }));

    expect(materializedChallengeQuestionsError(generated)).toBeNull();
    expect(
      materializedChallengeQuestionsError([
        ...generated.slice(0, 4),
        {
          ...generated[4],
          generatorVersion: 2,
        },
      ]),
    ).toContain("Quran metadata");
  });
});
