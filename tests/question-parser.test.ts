import { describe, expect, it } from 'vitest';
import { parseQuestion } from '@/domain/question-parser';

describe('parseQuestion', () => {
  it('parses a passport-expiry question', () => {
    expect(parseQuestion("When does Dad's passport expire?")).toEqual({
      kind: 'passport-expiry',
      person: 'Dad',
    });
  });

  it('parses a date-of-birth question', () => {
    expect(parseQuestion("What is Sana's date of birth?")).toEqual({
      kind: 'date-of-birth',
      person: 'Sana',
    });
  });

  it('parses the next-90-days expiry question', () => {
    expect(parseQuestion('Which documents expire in the next 90 days?')).toEqual({
      kind: 'expiring-within-days',
      days: 90,
    });
  });

  it('refuses an unsupported question kind', () => {
    expect(parseQuestion('What is our home address?')).toEqual({ kind: 'unsupported' });
  });
});
