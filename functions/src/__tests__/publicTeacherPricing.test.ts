import { describe, expect, it } from "vitest";
import { publicTeacherPricingPlan } from "../publicTeacherPricing";

describe("publicTeacherPricingPlan", () => {
  it("preserves the regional price snapshot used by the public profile", () => {
    const result = publicTeacherPricingPlan("sa-plan", {
      mohaffezId: "teacher-1",
      title: "جلسة فردية",
      type: "single",
      mode: "online",
      priceEGP: 650,
      countryCode: "sa",
      countryName: "السعودية",
      currencyCode: "sar",
      currencyLabel: "ر.س",
      displayPrice: 50,
      fxRateToEGP: 13,
      sessionsCount: 1,
      isActive: true,
    });

    expect(result).toMatchObject({
      id: "sa-plan",
      countryCode: "SA",
      countryName: "السعودية",
      currencyCode: "SAR",
      currencyLabel: "ر.س",
      displayPrice: 50,
      fxRateToEGP: 13,
      priceEGP: 650,
    });
  });

  it("keeps legacy plans identifiable as global Egyptian fallbacks", () => {
    const result = publicTeacherPricingPlan("legacy-plan", {
      mohaffezId: "teacher-1",
      priceEGP: 100,
      sessionsCount: 1,
      isActive: true,
    });

    expect(result).toMatchObject({
      countryCode: "EG",
      countryName: "مصر",
      currencyCode: "EGP",
      currencyLabel: "ج.م",
      displayPrice: null,
      fxRateToEGP: 1,
    });
  });
});
