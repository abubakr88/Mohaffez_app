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
