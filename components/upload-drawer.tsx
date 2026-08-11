'use client';

import { useState, type FormEvent } from 'react';
import type { DocumentCategory, PersonSummary } from '@/data/repository';
import type { SafeDocumentDetail } from '@/services/document-response';

const categories: DocumentCategory[] = ['passport', 'identity', 'insurance', 'school', 'vehicle', 'visa', 'certificate', 'utility'];

export function UploadDrawer({ people, onClose, onUploaded }: { people: PersonSummary[]; onClose(): void; onUploaded(document: SafeDocumentDetail): void }) {
  const [error, setError] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setUploading(true);
    setError(null);
    const response = await fetch('/api/documents', { method: 'POST', body: new FormData(event.currentTarget) });
    const body = await response.json() as SafeDocumentDetail | { error?: { message?: string } };
    setUploading(false);
    if (!response.ok) { setError('error' in body ? body.error?.message ?? 'The document could not be indexed.' : 'The document could not be indexed.'); return; }
    onUploaded(body as SafeDocumentDetail);
  }

  return (
    <div aria-modal="true" className="drawer__backdrop" role="dialog" aria-labelledby="upload-title">
      <form className="upload-drawer" onSubmit={submit}>
        <header className="upload-drawer__header"><div><p className="eyebrow">Local ingestion</p><h2 id="upload-title">Add a synthetic record</h2></div><button className="icon-button" onClick={onClose} type="button">Close</button></header>
        <p className="upload-drawer__intro">KinVault accepts synthetic text, Markdown, or CSV fixtures up to 10 MB. Payment-card content is blocked before it is saved.</p>
        <label>Document title<input maxLength={160} name="title" required /></label>
        <label>Person<select defaultValue="" name="personId" required><option disabled value="">Choose a person</option>{people.map((person) => <option key={person.id} value={person.id}>{person.displayName}</option>)}</select></label>
        <label>Category<select defaultValue="" name="category" required><option disabled value="">Choose a category</option>{categories.map((category) => <option key={category} value={category}>{category}</option>)}</select></label>
        <label>Fixture file<input accept="text/plain,text/markdown,text/csv,.txt,.md,.csv" name="file" required type="file" /></label>
        {error && <p className="inline-message" role="status">{error}</p>}
        <footer className="upload-drawer__footer"><button className="quiet-button" onClick={onClose} type="button">Cancel</button><button className="secondary-button" disabled={uploading} type="submit">{uploading ? 'Indexing…' : 'Index document'}</button></footer>
      </form>
    </div>
  );
}
