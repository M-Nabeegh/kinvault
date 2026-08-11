import { describe, expect, it } from 'vitest';
import { sourceCitationDetails } from '../components/source-citation';

describe('source citation metadata', () => {
  it('keeps the indexed source available as plain metadata before source preview exists', () => {
    expect(sourceCitationDetails({
      documentId: 'demo-dad-passport',
      documentTitle: 'Dad Passport (Synthetic)',
      page: 2,
      field: 'Expiry date',
      value: '2026-11-09',
      confidence: 0.96,
    })).toEqual({
      label: 'Source result',
      title: 'Dad Passport (Synthetic)',
      detail: 'Page 2 · Expiry date: 2026-11-09',
    });
  });
});
