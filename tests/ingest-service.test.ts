import { afterEach, describe, expect, it } from 'vitest';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createDatabase } from '@/data/db';
import { DocumentRepository } from '@/data/repository';
import { DeterministicExtractionService } from '@/services/extraction-service';
import { IngestService } from '@/services/ingest-service';
import { DocumentStorage } from '@/services/document-storage';

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) rmSync(directory, { recursive: true, force: true });
});

function createIngestService() {
  const directory = mkdtempSync(join(tmpdir(), 'kinvault-ingest-'));
  temporaryDirectories.push(directory);
  const repository = new DocumentRepository(createDatabase(join(directory, 'vault.sqlite')));
  repository.savePerson({ id: 'person-ali', displayName: 'Ali Rowan', relationship: 'self', initials: 'AR' });
  return {
    directory,
    repository,
    service: new IngestService(repository, new DocumentStorage(join(directory, 'vault'), () => 'upload-1'), new DeterministicExtractionService()),
  };
}

describe('IngestService', () => {
  it('stores an allowed synthetic text upload and indexes its cited source field', async () => {
    const { repository, service } = createIngestService();
    const text = '# Page 1\n\n| Field | Label | Value | Confidence |\n| --- | --- | --- | --- |\n| policy_number | Policy number | SYN-2026-009 | 0.92 |';

    const result = await service.ingest({
      personId: 'person-ali', title: 'Synthetic policy', category: 'insurance', originalName: 'synthetic-policy.md',
      mimeType: 'text/markdown', bytes: new TextEncoder().encode(text), textHint: text,
    });

    expect(result).toMatchObject({
      status: 'accepted',
      document: { title: 'Synthetic policy', fields: [{ pageNumber: 1, fieldKey: 'policy_number', sourceText: 'Policy number: SYN-2026-009' }] },
    });
    expect(repository.listDocuments()).toHaveLength(1);
  });

  it('rejects payment-card content without creating a document row or vault file', async () => {
    const { directory, repository, service } = createIngestService();
    const text = 'Synthetic payment card\nCard number: 4111 1111 1111 1111\nCVV: 123';

    const result = await service.ingest({
      personId: 'person-ali', title: 'Card', category: 'identity', originalName: 'payment-card.txt',
      mimeType: 'text/plain', bytes: new TextEncoder().encode(text), textHint: text,
    });

    expect(result).toEqual({ status: 'rejected', code: 'sensitive_data', message: 'Payment-card number detected.' });
    expect(repository.listDocuments()).toHaveLength(0);
    expect(existsSync(join(directory, 'vault', 'upload-1'))).toBe(false);
  });
});
