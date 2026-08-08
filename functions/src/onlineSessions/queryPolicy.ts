export const ONLINE_REMINDER_WINDOW_MS = 5 * 60 * 1000;
export const AUTO_END_BATCH_SIZE = 100;

export function buildOnlineReminderQuery(
  collection: FirebaseFirestore.CollectionReference,
  windowLower: FirebaseFirestore.Timestamp,
  windowUpper: FirebaseFirestore.Timestamp,
): FirebaseFirestore.Query {
  return collection
    .where('status', '==', 'accepted')
    .where('sessionType', '==', 'online')
    .where('meetingReminderSent', '==', false)
    .where('meeting.joinWindowOpensAt', '>=', windowLower)
    .where('meeting.joinWindowOpensAt', '<=', windowUpper)
    .orderBy('meeting.joinWindowOpensAt', 'asc');
}

export function buildOverdueAcceptedSessionsQuery(
  collection: FirebaseFirestore.CollectionReference,
  cutoff: FirebaseFirestore.Timestamp,
): FirebaseFirestore.Query {
  return collection
    .where('status', '==', 'accepted')
    .where('meetingStartedAt', '<=', cutoff)
    .orderBy('meetingStartedAt', 'asc')
    .limit(AUTO_END_BATCH_SIZE);
}
