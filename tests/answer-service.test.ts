import { afterEach, describe, expect, it } from 'vitest';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createDatabase } from '@/data/db';
import { DocumentRepository } from '@/data/repository';
import { seedDemoData } from '@/data/seed';
import { DocumentStorage } from '@/services/document-storage';
import { AnswerService } from '@/services/answer-service';
import { citedPreviewFields } from '../components/source-preview-model';

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function seededAnswerService(): AnswerService {
  const directory = mkdtempSync(join(tmpdir(), 'kinvault-answer-'));
  temporaryDirectories.push(directory);
  const repository = new DocumentRepository(createDatabase(join(directory, 'vault.sqlite')));
  seedDemoData(repository, new DocumentStorage(join(directory, 'files')));
  return new AnswerService(repository);
}

function addExpiryDocument(input: { id: string; expiresOn: string; extractedExpiry: string }): AnswerService {
  const directory = mkdtempSync(join(tmpdir(), 'kinvault-answer-expiry-'));
  temporaryDirectories.push(directory);
  const repository = new DocumentRepository(createDatabase(join(directory, 'vault.sqlite')));
  repository.savePerson({ id: 'person-expiry', displayName: 'Expiry Test', relationship: 'test', initials: 'ET' });
  repository.saveUpload({
    id: input.id,
    personId: 'person-expiry',
    title: input.id,
    category: 'insurance',
    fileName: `${input.id}.md`,
    storagePath: `${input.id}/${input.id}.md`,
    mimeType: 'text/markdown',
    pageCount: 1,
    status: 'indexed',
    expiresOn: input.expiresOn,
  }, [{
    pageNumber: 1,
    fieldKey: 'expires_on',
    label: 'Coverage ends',
    value: input.extractedExpiry,
    confidence: 0.96,
    sourceText: `Coverage ends: ${input.extractedExpiry}`,
  }]);
  return new AnswerService(repository);
}

describe('AnswerService', () => {
  it("returns Dad's exact passport expiry with a complete source citation", () => {
    const result = seededAnswerService().answer("When does Dad's passport expire?");

    expect(result).toMatchObject({
      status: 'answered',
      answer: 'Dad Rowan’s passport expires on 2026-11-09.',
      confidence: 'high',
      citations: [{
        documentId: 'demo-dad-passport',
        documentTitle: 'Dad Passport (Synthetic)',
        fieldId: expect.any(String),
        page: 2,
        field: 'Expiry date',
        value: '2026-11-09',
        confidence: 0.96,
      }],
    });
  });

  it('marks a returned low-confidence field as needing verification', () => {
    const result = seededAnswerService().answer("What is Sana's date of birth?");

    expect(result).toMatchObject({
      status: 'answered',
      confidence: 'needs verification',
      citations: [expect.objectContaining({ value: '2004-04-18', confidence: 0.62 })],
    });
    expect(result.answer).toContain('needs verification');
  });

  it('returns not-found without citations when the requested DOB is absent', () => {
    const result = seededAnswerService().answer("What is Dad's date of birth?");

    expect(result).toEqual({
      status: 'not-found',
      answer: 'Not found in the vault.',
      confidence: 'needs verification',
      citations: [],
      followUp: 'Try searching the indexed documents instead.',
    });
  });

  it('returns only expiry records in the inclusive requested window', () => {
    const result = seededAnswerService().answer('Which documents expire within the next 90 days?', '2026-08-11');

    expect(result).toMatchObject({
      status: 'answered',
      citations: [{ documentId: 'demo-dad-passport', value: '2026-11-09' }],
    });
    expect(result.citations).toHaveLength(1);
  });

  it('includes extracted expiry fields on both inclusive expiry-window boundaries', () => {
    const start = addExpiryDocument({ id: 'starts-today', expiresOn: '2028-01-01', extractedExpiry: '2026-08-11' });
    const end = addExpiryDocument({ id: 'ends-window', expiresOn: '2028-01-01', extractedExpiry: '2026-08-13' });

    expect(start.answer('Which documents expire within the next 2 days?', '2026-08-11').citations.map((citation) => citation.documentId)).toEqual(['starts-today']);
    expect(end.answer('Which documents expire within the next 2 days?', '2026-08-11').citations.map((citation) => citation.documentId)).toEqual(['ends-window']);
  });

  it('excludes a field outside the window even when document expiry metadata is inside it', () => {
    const service = addExpiryDocument({ id: 'stale-metadata-inside', expiresOn: '2026-08-12', extractedExpiry: '2027-01-01' });

    expect(service.answer('Which documents expire within the next 2 days?', '2026-08-11')).toMatchObject({ status: 'not-found', citations: [] });
  });

  it('includes a field inside the window even when document expiry metadata is outside it', () => {
    const service = addExpiryDocument({ id: 'stale-metadata-outside', expiresOn: '2027-01-01', extractedExpiry: '2026-08-12' });

    expect(service.answer('Which documents expire within the next 2 days?', '2026-08-11')).toMatchObject({
      status: 'answered',
      citations: [expect.objectContaining({ documentId: 'stale-metadata-outside', value: '2026-08-12' })],
    });
  });

  it('keeps the Spotlight citation pinned to one field when labels repeat on a page', () => {
    const repository = new DocumentRepository(createDatabase());
    repository.savePerson({ id: 'person-dad', displayName: 'Dad Rowan', relationship: 'parent', initials: 'DR' });
    repository.saveUpload({
      id: 'document-passport', personId: 'person-dad', title: 'Dad Passport (Synthetic)', category: 'passport', fileName: 'dad.md', storagePath: 'document-passport/dad.md', mimeType: 'text/markdown', pageCount: 2, status: 'indexed',
    }, [
      { id: 'field-cited', pageNumber: 2, fieldKey: 'expires_on', label: 'Expiry date', value: '2026-11-09', confidence: 0.96, sourceText: 'Expiry date: 2026-11-09' },
      { id: 'field-other', pageNumber: 2, fieldKey: 'document_note', label: 'Expiry date', value: 'not the cited value', confidence: 0.96, sourceText: 'Expiry date: not the cited value' },
    ]);

    const citation = new AnswerService(repository).answer("When does Dad's passport expire?").citations[0];

    expect(citation).toMatchObject({ fieldId: 'field-cited' });
    expect(citedPreviewFields(repository.getDocument('document-passport')!.fields, citation).map((field) => field.id)).toEqual(['field-cited']);
  });
});
