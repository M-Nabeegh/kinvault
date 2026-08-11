'use client';

import { useEffect, useState } from 'react';
import type { SafeDocumentDetail } from '@/services/document-response';
import { citedPreviewFields, type SourcePreviewCitation } from './source-preview-model';

export function SourcePreview({ documentId, onClose, citation }: { documentId: string; onClose(): void; citation?: SourcePreviewCitation }) {
  const [document, setDocument] = useState<SafeDocumentDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void fetch(`/api/documents/${encodeURIComponent(documentId)}`, { cache: 'no-store' })
      .then(async (response) => {
        if (!response.ok) throw new Error('The cited document could not be opened.');
        return response.json() as Promise<SafeDocumentDetail>;
      })
      .then((value) => { if (active) setDocument(value); })
      .catch((caught) => { if (active) setError(caught instanceof Error ? caught.message : 'The cited document could not be opened.'); });
    return () => { active = false; };
  }, [documentId]);

  return (
    <div aria-modal="true" className="source-preview__backdrop" role="dialog" aria-labelledby="source-preview-title">
      <section className="source-preview">
        <header className="source-preview__header">
          <div><p className="eyebrow">Cited source</p><h2 id="source-preview-title">{document?.title ?? 'Opening source…'}</h2></div>
          <button className="icon-button" onClick={onClose} type="button">Close</button>
        </header>
        {error && <p className="inline-message" role="status">{error}</p>}
        {!document && !error && <p className="empty-copy">Loading cited pages…</p>}
        {document && (
          <div className="source-preview__body">
            <p className="source-preview__note">This preview shows indexed field excerpts from the synthetic fixture. File locations are kept on this device and are not exposed here.</p>
            <dl className="source-preview__fields">
              {(citation ? citedPreviewFields(document.fields, citation) : document.fields).map((field) => <div key={field.id}><dt>Page {field.pageNumber} · {field.label}</dt><dd><strong>{field.value}</strong><span>{field.sourceText}</span><small>{Math.round(field.confidence * 100)}% confidence · {field.reviewStatus}</small></dd></div>)}
            </dl>
          </div>
        )}
      </section>
    </div>
  );
}
