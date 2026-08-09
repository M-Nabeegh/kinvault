import { describe, expect, it } from 'vitest';
import { daysUntil, documentsExpiringBetween } from '@/domain/date-utils';

describe('date utilities', () => {
  it('counts calendar days until a date', () => {
    expect(daysUntil('2026-09-01', '2026-08-11')).toBe(21);
  });

  it('includes both boundaries of an expiry window', () => {
    expect(
      documentsExpiringBetween(
        ['2026-08-11', '2026-09-09', '2026-11-09', '2026-11-10'],
        '2026-08-11',
        '2026-11-09',
      ),
    ).toEqual(['2026-08-11', '2026-09-09', '2026-11-09']);
  });

  it('treats date-only values as UTC calendar days', () => {
    expect(daysUntil('2026-08-12', '2026-08-11T23:30:00-11:00')).toBe(1);
  });
});
