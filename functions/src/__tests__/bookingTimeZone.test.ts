import { describe, expect, it } from "vitest";
import {
  localDateTime,
  TEACHER_TIME_ZONE_ID,
  teacherLocalSnapshot,
  zonedDateTimeToUtc,
  zonedParts,
} from "../bookings/bookingTimeZone";

describe("booking time-zone conversion", () => {
  it("converts a Cairo 8 PM slot to the same instant shown at 10 AM in Los Angeles", () => {
    const instant = localDateTime("2026-01-12", "20:00", TEACHER_TIME_ZONE_ID);

    expect(instant?.toISOString()).toBe("2026-01-12T18:00:00.000Z");
    expect(zonedParts(instant!, "America/Los_Angeles")).toMatchObject({
      year: 2026,
      month: 1,
      day: 12,
      hour: 10,
      minute: 0,
    });
  });

  it("keeps the teacher snapshot while another time zone moves to the next day", () => {
    const instant = localDateTime("2026-01-12", "23:30", TEACHER_TIME_ZONE_ID)!;

    expect(teacherLocalSnapshot(instant, TEACHER_TIME_ZONE_ID)).toEqual({
      localDate: "2026-01-12",
      localTime: "23:30",
      dayOfWeek: 1,
    });
    expect(zonedParts(instant, "Asia/Tokyo")).toMatchObject({
      year: 2026,
      month: 1,
      day: 13,
      hour: 6,
      minute: 30,
    });
  });

  it("rejects a nonexistent DST wall time", () => {
    expect(localDateTime("2026-03-08", "02:30", "America/New_York")).toBeNull();
  });

  it("selects the first occurrence of an ambiguous DST wall time", () => {
    const instant = zonedDateTimeToUtc(
      {year: 2026, month: 11, day: 1, hour: 1, minute: 30, second: 0},
      "America/New_York",
    );

    expect(instant?.toISOString()).toBe("2026-11-01T05:30:00.000Z");
  });

  it("uses Cairo winter and summer offsets from IANA data", () => {
    expect(localDateTime("2026-01-15", "20:00", TEACHER_TIME_ZONE_ID)?.toISOString())
      .toBe("2026-01-15T18:00:00.000Z");
    expect(localDateTime("2026-07-15", "20:00", TEACHER_TIME_ZONE_ID)?.toISOString())
      .toBe("2026-07-15T17:00:00.000Z");
  });

  it("rejects Cairo's nonexistent wall time at the DST transition", () => {
    expect(localDateTime("2026-04-24", "00:30", TEACHER_TIME_ZONE_ID)).toBeNull();
  });

  it("selects the first Cairo occurrence when DST ends", () => {
    const instant = localDateTime("2026-10-29", "23:30", TEACHER_TIME_ZONE_ID);
    expect(instant?.toISOString()).toBe("2026-10-29T20:30:00.000Z");
  });
});
