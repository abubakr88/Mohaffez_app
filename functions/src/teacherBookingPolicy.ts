export function isAcceptingNewBookings(
  teacher: FirebaseFirestore.DocumentData | undefined,
): boolean {
  // Existing teacher documents predate this setting and remain available.
  return teacher?.acceptingNewBookings !== false;
}
