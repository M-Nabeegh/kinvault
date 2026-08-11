import type { SourceCitation } from '@/domain/types';

export type PreviewField = { id?: string; pageNumber: number; label: string };
export type CitationField = PreviewField & { id: string; value: string; confidence: number };
export type SourcePreviewCitation = SourceCitation;

export function citedPreviewFields<T extends PreviewField>(fields: T[], citation: Pick<SourcePreviewCitation, 'page' | 'field' | 'fieldId'>): T[] {
  return fields.filter((field) => field.pageNumber === citation.page && field.label === citation.field && field.id === citation.fieldId);
}

export function documentCitation(document: { id: string; title: string; fields: CitationField[] }): SourcePreviewCitation | null {
  const field = document.fields[0];
  if (!field) return null;
  return { documentId: document.id, documentTitle: document.title, page: field.pageNumber, field: field.label, value: field.value, confidence: field.confidence, fieldId: field.id };
}
