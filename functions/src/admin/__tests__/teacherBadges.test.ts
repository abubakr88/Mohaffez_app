import { describe, expect, it } from "vitest";
import {
  foundingBadgeNeedsChange,
  isFoundingBadgeEnabled,
  sanitizeBadgeReason,
  validateFoundingBadgeTarget,
} from "../teacherBadges";

describe("founding teacher badge policy", () => {
  it("handles users without a badges field as inactive", () => {
    expect(isFoundingBadgeEnabled({ role: "mohaffez" })).toBe(false);
    expect(isFoundingBadgeEnabled({ badges: null })).toBe(false);
  });

  it("reads an enabled founding teacher badge", () => {
    expect(
      isFoundingBadgeEnabled({
        badges: { foundingTeacher: { enabled: true } },
      }),
    ).toBe(true);
  });

  it("treats duplicate grant and revoke requests as no change", () => {
    expect(foundingBadgeNeedsChange(true, true)).toBe(false);
    expect(foundingBadgeNeedsChange(false, false)).toBe(false);
    expect(foundingBadgeNeedsChange(false, true)).toBe(true);
    expect(foundingBadgeNeedsChange(true, false)).toBe(true);
  });

  it("accepts an active teacher and trims the optional reason", () => {
    expect(() =>
      validateFoundingBadgeTarget({ role: "mohaffez", status: "active" }, true),
    ).not.toThrow();
    expect(sanitizeBadgeReason("  launch cohort  ")).toBe("launch cohort");
    expect(sanitizeBadgeReason("   ")).toBeNull();
  });

  it("rejects non-teachers", () => {
    expect(() =>
      validateFoundingBadgeTarget({ role: "student", status: "active" }, true),
    ).toThrowError(/target-not-teacher/);
  });

  it("rejects deleted accounts", () => {
    expect(() =>
      validateFoundingBadgeTarget(
        { role: "mohaffez", status: "deleted" },
        true,
      ),
    ).toThrowError(/account-deleted/);
    expect(() =>
      validateFoundingBadgeTarget(
        { role: "mohaffez", status: "active", isDeleted: true },
        true,
      ),
    ).toThrowError(/account-deleted/);
  });

  it("blocks grants to suspended teachers but permits revocation", () => {
    expect(() =>
      validateFoundingBadgeTarget(
        { role: "mohaffez", status: "suspended" },
        true,
      ),
    ).toThrowError(/account-suspended/);
    expect(() =>
      validateFoundingBadgeTarget(
        { role: "mohaffez", status: "suspended" },
        false,
      ),
    ).not.toThrow();
  });

  it("limits internal reasons to 500 characters", () => {
    expect(() => sanitizeBadgeReason("x".repeat(501))).toThrowError(
      /reason-too-long/,
    );
  });
});
