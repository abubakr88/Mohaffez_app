import { describe, expect, it } from 'vitest';
import {
  ageAtDate,
  allowedLocalDayKeys,
  canRetryTrialRequest,
  intervalIsInsideWindow,
  localDayKey,
  normalizeTrialStudentPreparation,
} from '../trialSessionPolicy';

describe('trial session local-day policy', () => {
  it('uses the student local day around UTC midnight', () => {
    const instant = new Date('2026-06-20T22:30:00.000Z');
    expect(localDayKey(instant, 180)).toBe('2026-06-21');
  });

  it('allows local today, tomorrow, and the day after tomorrow', () => {
    const now = new Date('2026-06-20T22:30:00.000Z');
    expect([...allowedLocalDayKeys(now, 180)]).toEqual([
      '2026-06-21',
      '2026-06-22',
      '2026-06-23',
    ]);
  });

  it('requires the full proposed session to fit in the student window', () => {
    expect(intervalIsInsideWindow(200, 300, 100, 400)).toBe(true);
    expect(intervalIsInsideWindow(50, 300, 100, 400)).toBe(false);
    expect(intervalIsInsideWindow(200, 450, 100, 400)).toBe(false);
  });
});

describe('trial session retry policy', () => {
  it('allows another request only after the teacher rejects the proposed windows', () => {
    expect(canRetryTrialRequest('rejected_teacher')).toBe(true);
    expect(canRetryTrialRequest('pending_teacher')).toBe(false);
    expect(canRetryTrialRequest('awaiting_student_confirmation')).toBe(false);
    expect(canRetryTrialRequest('confirmed')).toBe(false);
    expect(canRetryTrialRequest('completed')).toBe(false);
    expect(canRetryTrialRequest('student_no_show')).toBe(false);
    expect(canRetryTrialRequest('rejected_student')).toBe(false);
  });
});

describe('trial student age', () => {
  it('calculates age around the birthday boundary', () => {
    const birthDate = new Date('2000-07-24T00:00:00.000Z');
    expect(ageAtDate(birthDate, new Date('2026-07-23T12:00:00.000Z')))
      .toBe(25);
    expect(ageAtDate(birthDate, new Date('2026-07-24T12:00:00.000Z')))
      .toBe(26);
  });

  it('rejects future or implausible birth dates', () => {
    expect(ageAtDate(
      new Date('2030-01-01T00:00:00.000Z'),
      new Date('2026-07-23T00:00:00.000Z'),
    )).toBeNull();
    expect(ageAtDate(
      new Date('1800-01-01T00:00:00.000Z'),
      new Date('2026-07-23T00:00:00.000Z'),
    )).toBeNull();
  });
});

describe('trial student preparation', () => {
  it('normalizes valid answers and trims the optional note', () => {
    expect(normalizeTrialStudentPreparation({
      currentLevel: 'reads_with_errors',
      learningGoal: 'recitation_correction',
      memorizationLevel: 'one_to_five_juz',
      note: '  أحتاج مساعدة في مخارج الحروف  ',
    })).toEqual({
      currentLevel: 'reads_with_errors',
      learningGoal: 'recitation_correction',
      memorizationLevel: 'one_to_five_juz',
      note: 'أحتاج مساعدة في مخارج الحروف',
    });
  });

  it('rejects unknown choices or an oversized note', () => {
    expect(normalizeTrialStudentPreparation({
      currentLevel: 'unknown',
      learningGoal: 'tajweed',
      memorizationLevel: 'none',
      note: '',
    })).toBeNull();
    expect(normalizeTrialStudentPreparation({
      currentLevel: 'complete_beginner',
      learningGoal: 'tajweed',
      memorizationLevel: 'none',
      note: 'x'.repeat(251),
    })).toBeNull();
  });
});
