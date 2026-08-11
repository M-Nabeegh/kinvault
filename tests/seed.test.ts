import { afterEach, describe, expect, it } from 'vitest';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createDatabase } from '@/data/db';
import { DocumentRepository } from '@/data/repository';
import { seedDemoData } from '@/data/seed';
import { DocumentStorage } from '@/services/document-storage';

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

describe('seedDemoData', () => {
  it('creates four synthetic documents and a pending review item without duplication', () => {
    const directory = mkdtempSync(join(tmpdir(), 'kinvault-seed-'));
    temporaryDirectories.push(directory);
    const repository = new DocumentRepository(createDatabase(join(directory, 'vault.sqlite')));
    const storage = new DocumentStorage(join(directory, 'vault'));

    seedDemoData(repository, storage);
    seedDemoData(repository, storage);

    expect(repository.listDocuments()).toHaveLength(4);
    expect(repository.listReviewItems()).toEqual([expect.objectContaining({ reviewStatus: 'pending' })]);
  });

  it('reconciles a database that contains only one seeded document', () => {
    const directory = mkdtempSync(join(tmpdir(), 'kinvault-seed-'));
    temporaryDirectories.push(directory);
    const repository = new DocumentRepository(createDatabase(join(directory, 'vault.sqlite')));
    const storage = new DocumentStorage(join(directory, 'vault'));
    repository.savePerson({ id: 'demo-dad', displayName: 'Dad Rowan', relationship: 'parent', initials: 'DR' });
    repository.saveUpload({
      id: 'demo-dad-passport', personId: 'demo-dad', title: 'Dad Passport (Synthetic)', category: 'passport', fileName: 'dad-passport.md', storagePath: 'demo-dad-passport/dad-passport.md', mimeType: 'text/markdown', pageCount: 2, status: 'indexed', expiresOn: '2026-11-09',
    }, [{ pageNumber: 2, fieldKey: 'expires_on', label: 'Expiry date', value: '2026-11-09', confidence: 0.96, sourceText: 'Expiry date: 2026-11-09' }]);

    seedDemoData(repository, storage);

    expect(repository.listDocuments()).toHaveLength(4);
    expect(repository.listPeople()).toHaveLength(4);
    expect(repository.listReviewItems()).toEqual([expect.objectContaining({ reviewStatus: 'pending' })]);
  });
});
