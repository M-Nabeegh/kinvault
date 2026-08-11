'use client';

import { useState } from 'react';
import type { ReviewItem } from '@/data/repository';
import { SourcePreview } from './source-preview';
import type { SourcePreviewCitation } from './source-preview-model';

export function ReviewQueue({ initialItems }: { initialItems: ReviewItem[] }) {
  const [items, setItems] = useState(initialItems);
  const [editing, setEditing] = useState<string | null>(null);
  const [values, setValues] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState<string | null>(null);
  const [sourceCitation, setSourceCitation] = useState<SourcePreviewCitation | null>(null);

  async function resolve(item: ReviewItem, action: 'accept' | 'dismiss' | 'correct') {
    const value = action === 'correct' ? values[item.id]?.trim() : undefined;
    if (action === 'correct' && !value) { setError('Enter the corrected value before saving.'); return; }
    setError(null);
    setPending(item.id);
    const response = await fetch(`/api/review/${encodeURIComponent(item.id)}`, { method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify(value ? { action, value } : { action }) });
    setPending(null);
    if (!response.ok) { const body = await response.json() as { error?: { message?: string } }; setError(body.error?.message ?? 'The review decision could not be saved.'); return; }
    setItems((current) => current.filter((candidate) => candidate.id !== item.id));
    setEditing(null);
    window.dispatchEvent(new Event('kinvault:dashboard-mutated'));
  }

  return (
    <section className="review-queue" aria-labelledby="review-heading">
      <header className="records-panel__header"><div><p className="eyebrow">Field verification</p><h1 id="review-heading">Needs review</h1><p>Confirm, correct, or dismiss uncertain extracted fields. The original cited text stays intact.</p></div><span className="review-queue__count">{items.length} open</span></header>
      {error && <p className="inline-message" role="status">{error}</p>}
      {!items.length ? <p className="empty-copy">No fields need a decision.</p> : <div className="review-queue__list">{items.map((item) => <article className="review-card" key={item.id}><div className="review-card__meta"><p className="eyebrow">{item.personName} · {item.documentTitle}</p><span>Page {item.pageNumber} citation</span></div><h2>{item.label}</h2><p className="review-card__value">{item.value}</p><p className="review-card__source">Source: {item.sourceText} · {item.reason} · {Math.round(item.confidence * 100)}% confidence</p>{editing === item.id && <label className="review-card__edit">Corrected value<input autoFocus onChange={(event) => setValues((current) => ({ ...current, [item.id]: event.target.value }))} value={values[item.id] ?? item.value} /></label>}<footer><button className="quiet-button" onClick={() => setSourceCitation({ documentId: item.documentId, documentTitle: item.documentTitle, page: item.pageNumber, field: item.label, value: item.value, confidence: item.confidence, fieldId: item.fieldId })} type="button">Open source</button><button className="quiet-button" disabled={pending === item.id} onClick={() => void resolve(item, 'dismiss')} type="button">Dismiss</button>{editing === item.id ? <><button className="quiet-button" onClick={() => setEditing(null)} type="button">Cancel edit</button><button className="secondary-button" disabled={pending === item.id} onClick={() => void resolve(item, 'correct')} type="button">Save correction</button></> : <><button className="quiet-button" onClick={() => { setValues((current) => ({ ...current, [item.id]: item.value })); setEditing(item.id); }} type="button">Edit</button><button className="secondary-button" disabled={pending === item.id} onClick={() => void resolve(item, 'accept')} type="button">Accept</button></>}</footer></article>)}</div>}
      {sourceCitation && <SourcePreview citation={sourceCitation} documentId={sourceCitation.documentId} onClose={() => setSourceCitation(null)} />}
    </section>
  );
}
