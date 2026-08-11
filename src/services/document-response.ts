import type { DocumentDetail, DocumentSummary, ExtractedField } from '@/data/repository';

export type SafeDocumentDetail = Omit<DocumentDetail, 'storagePath'>;

/** Keeps vault-relative storage locations on the server while preserving field provenance for the UI. */
export function safeDocumentDetail(document: DocumentDetail): SafeDocumentDetail {
  const { storagePath: _storagePath, ...safe } = document;
  return safe;
}

export type DocumentTimeline = { person: { id: string; displayName: string; relationship: string; initials: string }; documents: DocumentSummary[] };
export type SafeExtractedField = Pick<ExtractedField, 'id' | 'documentId' | 'pageNumber' | 'fieldKey' | 'label' | 'value' | 'confidence' | 'sourceText' | 'reviewStatus'>;
