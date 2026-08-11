import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { DocumentCategory, DocumentRepository } from './repository';
import { DeterministicExtractionService } from '@/services/extraction-service';
import type { DocumentStorage } from '@/services/document-storage';

const fixtureRoot = join(process.cwd(), 'data/demo-documents');
const people = [
  { id: 'demo-dad', displayName: 'Dad Rowan', relationship: 'parent', initials: 'DR' },
  { id: 'demo-sana', displayName: 'Sana Rowan', relationship: 'sibling', initials: 'SR' },
  { id: 'demo-ali', displayName: 'Ali Rowan', relationship: 'self', initials: 'AR' },
  { id: 'demo-family', displayName: 'Rowan Household', relationship: 'household', initials: 'RH' },
];
const fixtures: Array<{ id: string; personId: string; name: string; title: string; category: DocumentCategory; expiresOn?: string }> = [
  { id: 'demo-dad-passport', personId: 'demo-dad', name: 'dad-passport.md', title: 'Dad Passport (Synthetic)', category: 'passport', expiresOn: '2026-11-09' },
  { id: 'demo-sana-id', personId: 'demo-sana', name: 'sana-id-card.md', title: 'Sana ID Card (Synthetic)', category: 'identity', expiresOn: '2028-04-18' },
  { id: 'demo-ali-insurance', personId: 'demo-ali', name: 'ali-insurance.md', title: 'Ali Insurance (Synthetic)', category: 'insurance', expiresOn: '2027-01-31' },
  { id: 'demo-family-utility', personId: 'demo-family', name: 'family-utility.md', title: 'Family Utility (Synthetic)', category: 'utility' },
];

export function seedDemoData(repository: DocumentRepository, storage: DocumentStorage): void {
  for (const person of people) repository.savePerson(person);
  const extractor = new DeterministicExtractionService();
  for (const fixture of fixtures) {
    if (repository.hasDocument(fixture.id)) continue;
    const text = readFileSync(join(fixtureRoot, fixture.name), 'utf8');
    const stored = storage.save({ originalName: fixture.name, bytes: new TextEncoder().encode(text) });
    const extraction = extractor.extractFixtureText(text);
    repository.saveUpload({ id: fixture.id, personId: fixture.personId, title: fixture.title, category: fixture.category, fileName: stored.safeFileName, storagePath: stored.relativePath, mimeType: 'text/markdown', pageCount: extraction.pageCount, status: extraction.fields.some((field) => field.confidence < 0.75) ? 'review' : 'indexed', expiresOn: fixture.expiresOn }, extraction.fields);
  }
}
