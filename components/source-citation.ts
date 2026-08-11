import type { SourceCitation } from '@/domain/types';

export function sourceCitationDetails(citation: SourceCitation): { label: string; title: string; detail: string } {
  return {
    label: 'Source result',
    title: citation.documentTitle,
    detail: `Page ${citation.page} · ${citation.field}: ${citation.value}`,
  };
}
