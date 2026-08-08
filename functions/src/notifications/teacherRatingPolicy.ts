export type SessionRatingData = Record<string, unknown>;

const numericValue = (value: unknown): number | null => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  return value;
};

/**
 * Converts both the new explicit five-point rating and legacy ratings to the
 * five-point scale used by teacher profiles.
 */
export function normalizeTeacherRating(
  data: SessionRatingData
): number | null {
  const rating = numericValue(data.teacherRating);
  if (rating == null || rating <= 0) return null;

  const scale = numericValue(data.teacherRatingScale);
  if (scale === 5) {
    return rating <= 5 ? rating : null;
  }
  if (scale === 10) {
    return rating <= 10 ? rating / 2 : null;
  }

  // Legacy releases did not persist a scale. Values above five came from the
  // former ten-point UI; older five-point values can be used as-is.
  if (rating <= 5) return rating;
  if (rating <= 10) return rating / 2;
  return null;
}

/**
 * Technical-only complaints remain available for support review but do not
 * change the teacher's public reputation.
 */
export function countsTowardTeacherRating(
  data: SessionRatingData
): boolean {
  return (
    data.teacherRatingScale === 5 &&
    normalizeTeacherRating(data) != null &&
    data.teacherRatingReason !== 'technical_only'
  );
}
