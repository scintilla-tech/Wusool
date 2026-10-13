import { describe, expect, it } from 'vitest';
import { dateOnly, isPastBusinessTime } from '../src/utils/date';

describe('dateOnly', () => {
  it('uses the Riyadh calendar date independently of the host timezone', () => {
    const alreadyNextDayInRiyadh = new Date('2026-10-11T21:30:00.000Z');

    expect(dateOnly(alreadyNextDayInRiyadh).toISOString()).toBe('2026-10-12T00:00:00.000Z');
  });

  it('evaluates attendance cutoff in Riyadh time', () => {
    expect(isPastBusinessTime('07:00', new Date('2026-10-12T03:59:00.000Z'))).toBe(false);
    expect(isPastBusinessTime('07:00', new Date('2026-10-12T04:00:00.000Z'))).toBe(true);
  });
});
