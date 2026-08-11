import type { PersonSummary } from '@/data/repository';

export function PeopleList({ people }: { people: PersonSummary[] }) {
  return (
    <nav aria-label="People in the vault" className="people-list">
      {people.map((person) => <a href={`#${person.id}`} key={person.id}><span className="people-list__initials">{person.initials}</span><span><strong>{person.displayName}</strong><small>{person.relationship} · {person.documentCount} {person.documentCount === 1 ? 'record' : 'records'}</small></span></a>)}
    </nav>
  );
}
