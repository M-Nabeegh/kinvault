import type { DocumentSummary, PersonSummary } from '@/data/repository';
import { StatusPill } from './status-pill';

export function PersonTimeline({ person, documents }: { person: PersonSummary; documents: DocumentSummary[] }) {
  return (
    <section className="person-timeline" id={person.id} aria-labelledby={`${person.id}-heading`}>
      <header><span className="person-timeline__initials">{person.initials}</span><div><p className="eyebrow">{person.relationship}</p><h2 id={`${person.id}-heading`}>{person.displayName}</h2></div></header>
      {documents.length ? <ol>{documents.map((document) => <li key={document.id}><span className="person-timeline__dot" /><div><strong>{document.title}</strong><p>{document.category} · indexed {new Intl.DateTimeFormat('en', { day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(document.createdAt))}</p></div>{document.expiresOn ? <time dateTime={document.expiresOn}>Expires {document.expiresOn}</time> : <StatusPill tone={document.status === 'review' ? 'review' : undefined}>{document.status === 'review' ? 'Needs review' : 'Indexed'}</StatusPill>}</li>)}</ol> : <p className="empty-copy">No records are indexed for this person.</p>}
    </section>
  );
}
