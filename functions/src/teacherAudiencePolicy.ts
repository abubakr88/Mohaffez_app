export type AudienceAgeGroup = "children" | "teens" | "adults";

type Data = Record<string, unknown>;

export function audienceAgeGroup(
  age: number,
  config: Data,
): AudienceAgeGroup {
  const rawChildren = Number(config.discoveryChildrenMaxAge ?? 10);
  const rawTeens = Number(config.discoveryTeenMaxAge ?? 15);
  const valid = Number.isInteger(rawChildren) &&
    Number.isInteger(rawTeens) &&
    rawChildren >= 0 &&
    rawChildren < rawTeens &&
    rawTeens <= 30;
  const childrenMax = valid ? rawChildren : 10;
  const teensMax = valid ? rawTeens : 15;
  if (age <= childrenMax) return "children";
  if (age <= teensMax) return "teens";
  return "adults";
}

function enabledFacetValue(value: unknown, key: string): boolean {
  return !!value &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    (value as Data)[key] === true;
}

export function teacherAcceptsAudience(
  teacher: Data,
  ageGroup: string,
  learnerGender: string,
  allowIncomplete: boolean,
): boolean {
  const audiences = teacher.learnerAudiences;
  if (audiences && typeof audiences === "object" &&
      !Array.isArray(audiences)) {
    const ageAudience = (audiences as Data)[ageGroup];
    const hasV2Selection = Object.values(audiences as Data)
      .some((value) => value && typeof value === "object" &&
        Object.values(value as Data).some((enabled) => enabled === true));
    if (hasV2Selection) {
      return enabledFacetValue(ageAudience, learnerGender);
    }
  }

  const legacyAges = teacher.learnerAgeGroups;
  const legacyGenders = teacher.learnerGenders;
  const hasLegacyAge = legacyAges && typeof legacyAges === "object" &&
    Object.values(legacyAges as Data).some((value) => value === true);
  const hasLegacyGender = legacyGenders &&
    typeof legacyGenders === "object" &&
    Object.values(legacyGenders as Data).some((value) => value === true);
  if (hasLegacyAge && hasLegacyGender) {
    return enabledFacetValue(legacyAges, ageGroup) &&
      enabledFacetValue(legacyGenders, learnerGender);
  }
  return allowIncomplete;
}
