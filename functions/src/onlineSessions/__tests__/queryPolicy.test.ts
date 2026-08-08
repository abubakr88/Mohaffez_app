import { describe, expect, it, vi } from 'vitest';
import {
  AUTO_END_BATCH_SIZE,
  buildOnlineReminderQuery,
  buildOverdueAcceptedSessionsQuery,
  ONLINE_REMINDER_WINDOW_MS,
} from '../queryPolicy';

describe('online session scheduled-query policy', () => {
  it('filters reminders to the due join-window in Firestore', () => {
    const finalQuery = { kind: 'due-online-reminders' };
    const orderBy = vi.fn().mockReturnValue(finalQuery);
    const upperWhere = vi.fn().mockReturnValue({ orderBy });
    const lowerWhere = vi.fn().mockReturnValue({ where: upperWhere });
    const reminderWhere = vi.fn().mockReturnValue({ where: lowerWhere });
    const typeWhere = vi.fn().mockReturnValue({ where: reminderWhere });
    const statusWhere = vi.fn().mockReturnValue({ where: typeWhere });
    const collection = {
      where: statusWhere,
    } as unknown as FirebaseFirestore.CollectionReference;
    const lower = { seconds: 100 } as unknown as FirebaseFirestore.Timestamp;
    const upper = { seconds: 400 } as unknown as FirebaseFirestore.Timestamp;

    const result = buildOnlineReminderQuery(collection, lower, upper);

    expect(ONLINE_REMINDER_WINDOW_MS).toBe(5 * 60 * 1000);
    expect(statusWhere).toHaveBeenCalledWith('status', '==', 'accepted');
    expect(typeWhere).toHaveBeenCalledWith('sessionType', '==', 'online');
    expect(reminderWhere).toHaveBeenCalledWith(
      'meetingReminderSent',
      '==',
      false,
    );
    expect(lowerWhere).toHaveBeenCalledWith(
      'meeting.joinWindowOpensAt',
      '>=',
      lower,
    );
    expect(upperWhere).toHaveBeenCalledWith(
      'meeting.joinWindowOpensAt',
      '<=',
      upper,
    );
    expect(orderBy).toHaveBeenCalledWith(
      'meeting.joinWindowOpensAt',
      'asc',
    );
    expect(result).toBe(finalQuery);
  });

  it('queries only accepted sessions before applying the overdue limit', () => {
    const finalQuery = { kind: 'overdue-accepted-sessions' };
    const limit = vi.fn().mockReturnValue(finalQuery);
    const orderBy = vi.fn().mockReturnValue({ limit });
    const cutoffWhere = vi.fn().mockReturnValue({ orderBy });
    const statusWhere = vi.fn().mockReturnValue({ where: cutoffWhere });
    const collection = {
      where: statusWhere,
    } as unknown as FirebaseFirestore.CollectionReference;
    const cutoff = { seconds: 500 } as unknown as FirebaseFirestore.Timestamp;

    const result = buildOverdueAcceptedSessionsQuery(collection, cutoff);

    expect(statusWhere).toHaveBeenCalledWith('status', '==', 'accepted');
    expect(cutoffWhere).toHaveBeenCalledWith(
      'meetingStartedAt',
      '<=',
      cutoff,
    );
    expect(orderBy).toHaveBeenCalledWith('meetingStartedAt', 'asc');
    expect(limit).toHaveBeenCalledWith(AUTO_END_BATCH_SIZE);
    expect(AUTO_END_BATCH_SIZE).toBe(100);
    expect(result).toBe(finalQuery);
  });
});
