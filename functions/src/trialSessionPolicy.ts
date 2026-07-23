const DAY_MS = 24 * 60 * 60_000;

export function localDayKey(
  date: Date,
  timezoneOffsetMinutes: number,
): string {
  return new Date(date.getTime() + timezoneOffsetMinutes * 60_000)
    .toISOString()
    .substring(0, 10);
}

export function allowedLocalDayKeys(
  now: Date,
  timezoneOffsetMinutes: number,
): Set<string> {
  const localNow = new Date(
    now.getTime() + timezoneOffsetMinutes * 60_000,
  );
  const localDay = Date.UTC(
    localNow.getUTCFullYear(),
    localNow.getUTCMonth(),
    localNow.getUTCDate(),
  );

  return new Set(
    [0, 1, 2].map((offset) =>
      new Date(localDay + offset * DAY_MS).toISOString().substring(0, 10),
    ),
  );
}

export function intervalIsInsideWindow(
  startMs: number,
  endMs: number,
  windowStartMs: number,
  windowEndMs: number,
): boolean {
  return startMs >= windowStartMs && endMs <= windowEndMs;
}

export function canRetryTrialRequest(status: unknown): boolean {
  return status === 'rejected_teacher';
}

export function ageAtDate(
  birthDate: Date,
  referenceDate: Date,
): number | null {
  if (
    Number.isNaN(birthDate.getTime()) ||
    Number.isNaN(referenceDate.getTime()) ||
    birthDate > referenceDate
  ) {
    return null;
  }

  let age = referenceDate.getUTCFullYear() - birthDate.getUTCFullYear();
  const birthdayPassed =
    referenceDate.getUTCMonth() > birthDate.getUTCMonth() ||
    (referenceDate.getUTCMonth() === birthDate.getUTCMonth() &&
      referenceDate.getUTCDate() >= birthDate.getUTCDate());
  if (!birthdayPassed) age--;
  return age >= 0 && age <= 120 ? age : null;
}

export interface TrialStudentPreparation {
  currentLevel: string;
  learningGoal: string;
  memorizationLevel: string;
  note: string;
}

const CURRENT_LEVELS = new Set([
  'complete_beginner',
  'letters_foundation',
  'reads_with_errors',
  'fluent_reader',
  'memorizing_or_reviewing',
]);

const LEARNING_GOALS = new Set([
  'reading_foundation',
  'recitation_correction',
  'new_memorization',
  'memorization_review',
  'tajweed',
  'exam_or_ijazah',
]);

const MEMORIZATION_LEVELS = new Set([
  'none',
  'short_surahs',
  'less_than_one_juz',
  'one_to_five_juz',
  'more_than_five_juz',
  'full_quran',
]);

export function normalizeTrialStudentPreparation(
  value: unknown,
): TrialStudentPreparation | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const input = value as Record<string, unknown>;
  const currentLevel = typeof input.currentLevel === 'string'
    ? input.currentLevel.trim()
    : '';
  const learningGoal = typeof input.learningGoal === 'string'
    ? input.learningGoal.trim()
    : '';
  const memorizationLevel = typeof input.memorizationLevel === 'string'
    ? input.memorizationLevel.trim()
    : '';
  const note = typeof input.note === 'string' ? input.note.trim() : '';

  if (
    !CURRENT_LEVELS.has(currentLevel) ||
    !LEARNING_GOALS.has(learningGoal) ||
    !MEMORIZATION_LEVELS.has(memorizationLevel) ||
    note.length > 250
  ) {
    return null;
  }

  return {currentLevel, learningGoal, memorizationLevel, note};
}
