import type { SourceCitation } from '@/domain/types';

export type ExtractedFieldLike = {
  page?: number | null;
  label?: string | null;
  value: string;
  confidence: number;
};

export type DocumentLike = {
  id: string;
  title: string;
};

export function citationFor(field: ExtractedFieldLike, document: DocumentLike): SourceCitation {
  if (field.page == null || field.page < 1) {
    throw new Error('A citation requires a source page');
  }

  if (!field.label?.trim()) {
    throw new Error('A citation requires a source field label');
  }

  return {
    documentId: document.id,
    documentTitle: document.title,
    page: field.page,
    field: field.label,
    value: field.value,
    confidence: field.confidence,
  };
}
