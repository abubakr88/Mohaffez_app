import { describe, expect, it } from "vitest";
import { isAcceptingNewBookings } from "../teacherBookingPolicy";

describe("teacher booking policy", () => {
  it("keeps legacy teacher accounts available", () => {
    expect(isAcceptingNewBookings(undefined)).toBe(true);
    expect(isAcceptingNewBookings({})).toBe(true);
  });

  it("blocks only teachers who explicitly pause new bookings", () => {
    expect(isAcceptingNewBookings({ acceptingNewBookings: false })).toBe(false);
    expect(isAcceptingNewBookings({ acceptingNewBookings: true })).toBe(true);
  });
});
