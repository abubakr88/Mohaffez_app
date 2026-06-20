import { describe, expect, it } from 'vitest';
import {
  allowedLocalDayKeys,
  intervalIsInsideWindow,
  localDayKey,
} from '../trialSessionPolicy';

describe('trial session local-day policy', () => {
  it('uses the student local day around UTC midnight', () => {
    const instant = new Date('2026-06-20T22:30:00.000Z');
    expect(localDayKey(instant, 180)).toBe('2026-06-21');
  });

  it('allows local today, tomorrow, and the day after tomorrow', () => {
    const now = new Date('2026-06-20T22:30:00.000Z');
    expect([...allowedLocalDayKeys(now, 180)]).toEqual([
      '2026-06-21',
      '2026-06-22',
      '2026-06-23',
    ]);
  });

  it('requires the full proposed session to fit in the student window', () => {
    expect(intervalIsInsideWindow(200, 300, 100, 400)).toBe(true);
    expect(intervalIsInsideWindow(50, 300, 100, 400)).toBe(false);
    expect(intervalIsInsideWindow(200, 450, 100, 400)).toBe(false);
  });
});
