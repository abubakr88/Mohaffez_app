function nonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function finiteNumber(value: unknown, fallback = 0): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

/**
 * Builds the non-sensitive pricing snapshot used by the shared teacher
 * profile. Regional price metadata must remain attached to the EGP settlement
 * amount so clients can select the viewer's country without duplicate plans.
 */
export function publicTeacherPricingPlan(
  id: string,
  data: Record<string, unknown>,
): Record<string, unknown> {
  const countryCode = (nonEmptyString(data.countryCode) ?? "EG").toUpperCase();
  const currencyCode = (nonEmptyString(data.currencyCode) ?? "EGP").toUpperCase();
  const displayPrice = typeof data.displayPrice === "number" &&
      Number.isFinite(data.displayPrice)
    ? data.displayPrice
    : null;
  const fxRateToEGP = typeof data.fxRateToEGP === "number" &&
      Number.isFinite(data.fxRateToEGP) && data.fxRateToEGP > 0
    ? data.fxRateToEGP
    : 1;

  return {
    id,
    mohaffezId: nonEmptyString(data.mohaffezId),
    title: nonEmptyString(data.title) ?? "خطة سعر",
    type: nonEmptyString(data.type) ?? "single",
    mode: nonEmptyString(data.mode) ?? "online",
    priceEGP: finiteNumber(data.priceEGP),
    countryCode,
    countryName: nonEmptyString(data.countryName) ??
      (countryCode === "EG" ? "مصر" : countryCode),
    currencyCode,
    currencyLabel: nonEmptyString(data.currencyLabel) ??
      (currencyCode === "EGP" ? "ج.م" : currencyCode),
    displayPrice,
    fxRateToEGP,
    sessionsCount: Math.max(0, Math.trunc(finiteNumber(data.sessionsCount))),
    sessionDurationMinutes:
      typeof data.sessionDurationMinutes === "number"
        ? Math.trunc(data.sessionDurationMinutes)
        : null,
    validityDays:
      typeof data.validityDays === "number" ? data.validityDays : null,
    sessionsPerWeek:
      typeof data.sessionsPerWeek === "number" ? data.sessionsPerWeek : null,
    isActive: true,
    isFreeTrialAvailable: data.isFreeTrialAvailable === true,
    description: nonEmptyString(data.description),
  };
}
