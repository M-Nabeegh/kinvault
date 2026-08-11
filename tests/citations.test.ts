import { describe, expect, it } from 'vitest';
import { citationFor } from '@/domain/citations';

const document = { id: 'document-7', title: 'Dad Passport' };

describe('citationFor', () => {
  it('preserves the document and extracted field provenance exactly', () => {
    expect(
      citationFor(
        { id: 'field-expiry', page: 2, label: 'Expiry date', value: '2026-11-09', confidence: 0.92 },
        document,
      ),
    ).toEqual({
      documentId: 'document-7',
      documentTitle: 'Dad Passport',
      fieldId: 'field-expiry',
      page: 2,
      field: 'Expiry date',
      value: '2026-11-09',
      confidence: 0.92,
    });
  });

  it('rejects a field without a source page', () => {
    expect(() => citationFor({ id: 'field-expiry', label: 'Expiry date', value: '2026-11-09', confidence: 0.92 }, document)).toThrow();
  });

  it('rejects a field without a source label', () => {
    expect(() => citationFor({ id: 'field-expiry', page: 2, value: '2026-11-09', confidence: 0.92 }, document)).toThrow();
  });
});
