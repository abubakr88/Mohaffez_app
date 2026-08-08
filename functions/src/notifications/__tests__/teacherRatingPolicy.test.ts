import { describe, expect, it } from 'vitest';
import {
  countsTowardTeacherRating,
  normalizeTeacherRating,
} from '../teacherRatingPolicy';

describe('teacher rating policy', () => {
  it('keeps explicit five-point ratings unchanged', () => {
    expect(
      normalizeTeacherRating({
        teacherRating: 4,
        teacherRatingScale: 5,
      })
    ).toBe(4);
  });

  it('normalizes explicit and legacy ten-point ratings', () => {
    expect(
      normalizeTeacherRating({
        teacherRating: 8,
        teacherRatingScale: 10,
      })
    ).toBe(4);
    expect(normalizeTeacherRating({ teacherRating: 9 })).toBe(4.5);
  });

  it('rejects ratings outside their declared scale', () => {
    expect(
      normalizeTeacherRating({
        teacherRating: 6,
        teacherRatingScale: 5,
      })
    ).toBeNull();
    expect(normalizeTeacherRating({ teacherRating: 0 })).toBeNull();
  });

  it('excludes technical-only feedback from public reputation', () => {
    expect(
      countsTowardTeacherRating({
        teacherRating: 2,
        teacherRatingScale: 5,
        teacherRatingReason: 'technical_only',
      })
    ).toBe(false);
    expect(
      countsTowardTeacherRating({
        teacherRating: 2,
        teacherRatingScale: 5,
        teacherRatingReason: 'unclear_explanation',
      })
    ).toBe(true);
  });

  it('keeps legacy ratings historical even when they can be normalized', () => {
    expect(
      countsTowardTeacherRating({
        teacherRating: 10,
      })
    ).toBe(false);
    expect(
      countsTowardTeacherRating({
        teacherRating: 8,
        teacherRatingScale: 10,
      })
    ).toBe(false);
  });
});
