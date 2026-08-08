import { describe, expect, it } from "vitest";
import {
  audienceAgeGroup,
  teacherAcceptsAudience,
} from "../teacherAudiencePolicy";

describe("teacher audience policy", () => {
  it("uses configurable non-overlapping age boundaries", () => {
    const config = {
      discoveryChildrenMaxAge: 10,
      discoveryTeenMaxAge: 15,
    };
    expect(audienceAgeGroup(10, config)).toBe("children");
    expect(audienceAgeGroup(11, config)).toBe("teens");
    expect(audienceAgeGroup(15, config)).toBe("teens");
    expect(audienceAgeGroup(16, config)).toBe("adults");
    expect(audienceAgeGroup(12, {
      discoveryChildrenMaxAge: 12,
      discoveryTeenMaxAge: 17,
    })).toBe("children");
  });

  it("supports women plus boys and girls without allowing adult men", () => {
    const teacher = {
      learnerAudiences: {
        children: { male: true, female: true },
        teens: { female: true },
        adults: { female: true },
      },
    };
    expect(teacherAcceptsAudience(teacher, "children", "male", false))
      .toBe(true);
    expect(teacherAcceptsAudience(teacher, "children", "female", false))
      .toBe(true);
    expect(teacherAcceptsAudience(teacher, "adults", "female", false))
      .toBe(true);
    expect(teacherAcceptsAudience(teacher, "adults", "male", false))
      .toBe(false);
  });

  it("keeps v1 cross-product compatibility and controls missing profiles", () => {
    const legacy = {
      learnerAgeGroups: { children: true, adults: true },
      learnerGenders: { female: true },
    };
    expect(teacherAcceptsAudience(legacy, "children", "female", false))
      .toBe(true);
    expect(teacherAcceptsAudience(legacy, "children", "male", true))
      .toBe(false);
    expect(teacherAcceptsAudience({}, "children", "male", true)).toBe(true);
    expect(teacherAcceptsAudience({}, "children", "male", false)).toBe(false);
  });
});
