import { afterEach, describe, expect, it } from 'vitest';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createDatabase } from '@/data/db';
import { DocumentRepository } from '@/data/repository';

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

describe('DocumentRepository', () => {
  it('saves a person, document, and field then summarizes dashboard expiries', () => {
    const directory = mkdtempSync(join(tmpdir(), 'kinvault-repository-'));
    temporaryDirectories.push(directory);
    const database = createDatabase(join(directory, 'vault.sqlite'));
    const repository = new DocumentRepository(database);

    repository.savePerson({ id: 'person-dad', displayName: 'Dad Rowan', relationship: 'parent', initials: 'DR' });
    repository.saveUpload(
      {
        id: 'document-passport',
        personId: 'person-dad',
        title: 'Dad Passport',
        category: 'passport',
        fileName: 'dad-passport.md',
        storagePath: 'document-passport/dad-passport.md',
        mimeType: 'text/markdown',
        pageCount: 2,
        status: 'indexed',
        expiresOn: '2026-11-09',
      },
      [{ pageNumber: 2, fieldKey: 'expires_on', label: 'Expiry date', value: '2026-11-09', confidence: 0.96, sourceText: 'Expiry date: 2026-11-09' }],
    );

    expect(repository.listDashboard()).toMatchObject({
      documentCount: 1,
      categoryCounts: [{ category: 'passport', count: 1 }],
      nextExpiry: expect.objectContaining({ id: 'document-passport', expiresOn: '2026-11-09' }),
    });
    expect(repository.getDocument('document-passport')?.fields).toEqual([
      expect.objectContaining({ fieldKey: 'expires_on', pageNumber: 2, value: '2026-11-09' }),
    ]);
  });
});
