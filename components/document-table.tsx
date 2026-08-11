'use client';

import { useMemo, useState } from 'react';
import type { DocumentCategory, DocumentStatus, DocumentSummary, PersonSummary } from '@/data/repository';
import type { SafeDocumentDetail } from '@/services/document-response';
import { SourcePreview } from './source-preview';
import { documentCitation } from './source-preview-model';
import { UploadDrawer } from './upload-drawer';
import { StatusPill } from './status-pill';

const categories: Array<DocumentCategory | ''> = ['', 'passport', 'identity', 'insurance', 'school', 'vehicle', 'visa', 'certificate', 'utility'];
const statuses: Array<DocumentStatus | ''> = ['', 'indexed', 'review'];

export function DocumentTable({ initialDocuments, people }: { initialDocuments: DocumentSummary[]; people: PersonSummary[] }) {
  const [documents, setDocuments] = useState(initialDocuments);
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState<DocumentCategory | ''>('');
  const [personId, setPersonId] = useState('');
  const [status, setStatus] = useState<DocumentStatus | ''>('');
  const [showUpload, setShowUpload] = useState(false);
  const [sourceCitation, setSourceCitation] = useState<ReturnType<typeof documentCitation>>(null);
  const [error, setError] = useState<string | null>(null);

  async function refresh() {
    setError(null);
    const params = new URLSearchParams();
    if (category) params.set('category', category);
    if (personId) params.set('person', personId);
    if (status) params.set('status', status);
    const response = await fetch(`/api/documents?${params.toString()}`, { cache: 'no-store' });
    if (!response.ok) { setError('The document list could not refresh.'); return; }
    const payload = await response.json() as { documents: DocumentSummary[] };
    setDocuments(payload.documents);
  }

  const visibleDocuments = useMemo(() => documents.filter((document) => `${document.title} ${document.personName} ${document.category}`.toLowerCase().includes(search.toLowerCase())), [documents, search]);
  function uploaded(document: SafeDocumentDetail) {
    const person = people.find((candidate) => candidate.id === document.personId);
    setDocuments((current) => [{ id: document.id, personId: document.personId, personName: person?.displayName ?? 'Unknown person', title: document.title, category: document.category, status: document.status, expiresOn: document.expiresOn, createdAt: document.createdAt }, ...current]);
    setShowUpload(false);
    window.dispatchEvent(new Event('kinvault:dashboard-mutated'));
  }

  async function openCitation(document: DocumentSummary) {
    setError(null);
    const response = await fetch(`/api/documents/${encodeURIComponent(document.id)}`, { cache: 'no-store' });
    if (!response.ok) { setError('The cited document could not be opened.'); return; }
    const citation = documentCitation(await response.json() as SafeDocumentDetail);
    if (!citation) { setError('This document has no indexed field citation yet.'); return; }
    setSourceCitation(citation);
  }

  return (
    <section className="records-panel" aria-labelledby="documents-heading">
      <header className="records-panel__header"><div><p className="eyebrow">Cabinet index</p><h1 id="documents-heading">Documents</h1><p>Filter the local index, then open the field-level citation behind a record.</p></div><button className="secondary-button" onClick={() => setShowUpload(true)} type="button">Add document</button></header>
      <div className="document-filters"><label>Search<input onChange={(event) => setSearch(event.target.value)} placeholder="Name, person, category" value={search} /></label><label>Person<select onChange={(event) => setPersonId(event.target.value)} value={personId}><option value="">Everyone</option>{people.map((person) => <option key={person.id} value={person.id}>{person.displayName}</option>)}</select></label><label>Category<select onChange={(event) => setCategory(event.target.value as DocumentCategory | '')} value={category}>{categories.map((value) => <option key={value || 'all'} value={value}>{value || 'All categories'}</option>)}</select></label><label>Status<select onChange={(event) => setStatus(event.target.value as DocumentStatus | '')} value={status}>{statuses.map((value) => <option key={value || 'all'} value={value}>{value || 'All statuses'}</option>)}</select></label><button className="quiet-button" onClick={() => void refresh()} type="button">Apply filters</button></div>
      {error && <p className="inline-message" role="status">{error}</p>}
      <div className="document-table" role="table" aria-label="Indexed documents"><div className="document-table__head" role="row"><span>Document</span><span>Owner</span><span>Status</span><span>Source</span></div>{visibleDocuments.map((document) => <div className="document-table__row" key={document.id} role="row"><div><strong>{document.title}</strong><span>{document.category}{document.expiresOn ? ` · expires ${document.expiresOn}` : ''}</span></div><span>{document.personName}</span><StatusPill tone={document.status === 'review' ? 'review' : undefined}>{document.status === 'review' ? 'Needs review' : 'Indexed'}</StatusPill><button className="table-link" onClick={() => void openCitation(document)} type="button">View citations</button></div>)}{!visibleDocuments.length && <p className="empty-copy">No documents match these filters.</p>}</div>
      {showUpload && <UploadDrawer onClose={() => setShowUpload(false)} onUploaded={uploaded} people={people} />}
      {sourceCitation && <SourcePreview citation={sourceCitation} documentId={sourceCitation.documentId} onClose={() => setSourceCitation(null)} />}
    </section>
  );
}
