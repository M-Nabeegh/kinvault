import { describe, expect, it } from 'vitest';
import { sourceCitationDetails } from '../components/source-citation';
import { citedPreviewFields } from '../components/source-preview-model';

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

  it('shows only the cited page and field metadata in a source preview', () => {
    expect(citedPreviewFields([
      { id: 'page-1', pageNumber: 1, label: 'Name' },
      { id: 'page-2-expiry', pageNumber: 2, label: 'Expiry date' },
      { id: 'page-2-number', pageNumber: 2, label: 'Passport number' },
    ], { page: 2, field: 'Expiry date' }).map((field) => field.id)).toEqual(['page-2-expiry']);
  });
});
