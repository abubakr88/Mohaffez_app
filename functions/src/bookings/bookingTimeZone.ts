export const TEACHER_TIME_ZONE_ID = "Africa/Cairo";

export interface ZonedDateParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}

const formatterCache = new Map<string, Intl.DateTimeFormat>();

function formatter(timeZone: string): Intl.DateTimeFormat {
  const cached = formatterCache.get(timeZone);
  if (cached) return cached;
  const created = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    calendar: "gregory",
    numberingSystem: "latn",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  });
  formatterCache.set(timeZone, created);
  return created;
}

export function isValidTimeZone(value: unknown): value is string {
  if (typeof value !== "string" || value.trim().length === 0) return false;
  try {
    formatter(value.trim()).format(new Date(0));
    return true;
  } catch (_) {
    return false;
  }
}

export function zonedParts(date: Date, timeZone: string): ZonedDateParts {
  const values: Record<string, number> = {};
  for (const part of formatter(timeZone).formatToParts(date)) {
    if (part.type !== "literal") values[part.type] = Number(part.value);
  }
  return {
    year: values.year,
    month: values.month,
    day: values.day,
    hour: values.hour,
    minute: values.minute,
    second: values.second,
  };
}

function sameParts(a: ZonedDateParts, b: ZonedDateParts): boolean {
  return a.year === b.year && a.month === b.month && a.day === b.day &&
    a.hour === b.hour && a.minute === b.minute && a.second === b.second;
}

function offsetAt(date: Date, timeZone: string): number {
  const parts = zonedParts(date, timeZone);
  const representedAsUtc = Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
  );
  return representedAsUtc - Math.floor(date.getTime() / 1000) * 1000;
}

/**
 * Converts a wall-clock value in an IANA time zone to a real UTC instant.
 * Non-existent DST times return null. Ambiguous times use the first instant.
 */
export function zonedDateTimeToUtc(
  local: ZonedDateParts,
  timeZone: string,
): Date | null {
  if (!isValidTimeZone(timeZone)) return null;
  const naiveUtc = Date.UTC(
    local.year,
    local.month - 1,
    local.day,
    local.hour,
    local.minute,
    local.second,
  );
  const offsets = new Set<number>();
  for (const hours of [-36, -24, -12, 0, 12, 24, 36]) {
    offsets.add(offsetAt(new Date(naiveUtc + hours * 3_600_000), timeZone));
  }
  const matches = [...offsets]
    .map((offset) => new Date(naiveUtc - offset))
    .filter((candidate) => sameParts(zonedParts(candidate, timeZone), local))
    .sort((a, b) => a.getTime() - b.getTime());
  return matches[0] ?? null;
}

export function parseClock(value: unknown): {hour: number; minute: number} | null {
  if (typeof value !== "string") return null;
  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return {hour, minute};
}

export function minutesFromClock(value: unknown): number | null {
  const parsed = parseClock(value);
  return parsed ? parsed.hour * 60 + parsed.minute : null;
}

export function clockFromMinutes(value: number): string {
  const hour = Math.floor(value / 60);
  const minute = value % 60;
  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

export function dateKey(parts: Pick<ZonedDateParts, "year" | "month" | "day">): string {
  return `${String(parts.year).padStart(4, "0")}-` +
    `${String(parts.month).padStart(2, "0")}-` +
    `${String(parts.day).padStart(2, "0")}`;
}

export function parseDateKey(value: string): Pick<ZonedDateParts, "year" | "month" | "day"> | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const check = new Date(Date.UTC(year, month - 1, day));
  if (check.getUTCFullYear() !== year || check.getUTCMonth() !== month - 1 ||
      check.getUTCDate() !== day) return null;
  return {year, month, day};
}

export function addLocalDays(value: string, days: number): string {
  const parsed = parseDateKey(value);
  if (!parsed) throw new Error(`Invalid date key: ${value}`);
  const date = new Date(Date.UTC(parsed.year, parsed.month - 1, parsed.day + days));
  return dateKey({
    year: date.getUTCFullYear(),
    month: date.getUTCMonth() + 1,
    day: date.getUTCDate(),
  });
}

export function isoWeekday(value: string): number {
  const parsed = parseDateKey(value);
  if (!parsed) throw new Error(`Invalid date key: ${value}`);
  const jsDay = new Date(Date.UTC(parsed.year, parsed.month - 1, parsed.day)).getUTCDay();
  return jsDay === 0 ? 7 : jsDay;
}

export function localDateTime(
  localDate: string,
  clock: string,
  timeZone: string,
): Date | null {
  const date = parseDateKey(localDate);
  const time = parseClock(clock);
  if (!date || !time) return null;
  return zonedDateTimeToUtc({
    ...date,
    ...time,
    second: 0,
  }, timeZone);
}

export function teacherLocalSnapshot(date: Date, timeZone: string): {
  localDate: string;
  localTime: string;
  dayOfWeek: number;
} {
  const parts = zonedParts(date, timeZone);
  const localDate = dateKey(parts);
  return {
    localDate,
    localTime: clockFromMinutes(parts.hour * 60 + parts.minute),
    dayOfWeek: isoWeekday(localDate),
  };
}
