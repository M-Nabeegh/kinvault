import { PeopleList } from '../../components/people-list';
import { PersonTimeline } from '../../components/person-timeline';
import { KinVaultShell } from '../../components/kinvault-shell';
import { documentCitation } from '../../components/source-preview-model';
import { demoRepository } from '@/services/demo-vault';

export default function PeoplePage() {
  const repository = demoRepository();
  const people = repository.listPeople();
  const documents = repository.listDocuments();
  const citations = Object.fromEntries(documents.map((document) => [document.id, documentCitation(repository.getDocument(document.id)!)]));
  return <KinVaultShell activeSection="people"><section className="people-page"><header className="records-panel__header"><div><p className="eyebrow">Family map</p><h1>People</h1><p>Each timeline is a local index of the records held for that person.</p></div></header><PeopleList people={people} /><div className="people-timelines">{people.map((person) => <PersonTimeline citations={citations} documents={documents.filter((document) => document.personId === person.id)} key={person.id} person={person} />)}</div></section></KinVaultShell>;
}
