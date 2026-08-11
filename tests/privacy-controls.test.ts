import { afterEach, describe, expect, it } from 'vitest';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createDatabase } from '@/data/db';
import { DocumentRepository } from '@/data/repository';
import { DocumentStorage } from '@/services/document-storage';
import { VaultControls } from '@/services/vault-controls';
import { requestDocumentRemoval, requestVaultRemoval } from '@/services/privacy-requests';
import { GET as exportVault } from '../app/api/export/route';
import { DELETE as deleteVault } from '../app/api/vault/route';
import { dynamic as privacyPageRendering } from '../app/privacy/page';

const directories: string[] = [];

afterEach(() => {
  for (const directory of directories.splice(0)) rmSync(directory, { force: true, recursive: true });
});

function fixtureVault() {
  const root = mkdtempSync(join(tmpdir(), 'kinvault-privacy-'));
  directories.push(root);
  const database = createDatabase();
  const repository = new DocumentRepository(database);
  const storage = new DocumentStorage(root, () => 'doc-safe');
  repository.savePerson({ id: 'person-safe', displayName: 'Demo Rowan', relationship: 'self', initials: 'DR' });
  const stored = storage.save({ originalName: 'passport source.md', bytes: new TextEncoder().encode('Synthetic source fixture') });
  repository.saveUpload({ id: 'doc-safe', personId: 'person-safe', title: 'Passport (Synthetic)', category: 'passport', fileName: stored.safeFileName, storagePath: stored.relativePath, mimeType: 'text/markdown', pageCount: 1 }, [
    { id: 'field-safe', pageNumber: 1, fieldKey: 'expiry_date', label: 'Expiry date', value: '2030-01-02', confidence: 0.95, sourceText: 'Expiry date: 2030-01-02', reviewStatus: 'accepted' },
  ]);
  return { controls: new VaultControls(repository, storage), database, repository, storage, stored };
}

describe('privacy controls', () => {
  it('exports a local ZIP with synthetic-safe metadata and cited source fields, never an absolute vault path', async () => {
    const response = await exportVault();
    const text = new TextDecoder().decode(await response.arrayBuffer());

    expect(response.headers.get('content-type')).toContain('application/zip');
    expect(text).toContain('metadata.json');
    expect(text).toContain('"dataClassification": "synthetic-demo-data"');
    expect(text).toContain('Dad Passport (Synthetic)');
    expect(text).toContain('Expiry date');
    expect(text).not.toContain(process.cwd());
    expect(text).not.toMatch(/"storagePath"\s*:/);
  });

  it('removes one document, its extracted fields, and only its vault-relative file', () => {
    const { controls, database, repository, storage, stored } = fixtureVault();

    expect(controls.deleteDocument('doc-safe', 'DELETE DOCUMENT')).toEqual({ deleted: true, documentId: 'doc-safe' });
    expect(repository.getDocument('doc-safe')).toBeNull();
    expect(storage.exists(stored.relativePath)).toBe(false);
    expect(database.db.prepare('SELECT COUNT(*) AS count FROM extracted_fields WHERE document_id = ?').get('doc-safe')).toEqual({ count: 0 });
  });

  it('requires the exact vault-delete confirmation phrase before removing local vault data', () => {
    const { controls, repository, storage, stored } = fixtureVault();

    expect(controls.deleteVault('delete my vault')).toEqual({ deleted: false, reason: 'confirmation_required' });
    expect(repository.getDocument('doc-safe')).not.toBeNull();
    expect(storage.exists(stored.relativePath)).toBe(true);
    expect(controls.deleteVault('DELETE MY VAULT')).toEqual({ deleted: true, documentCount: 1 });
    expect(repository.listDocuments()).toEqual([]);
    expect(storage.exists(stored.relativePath)).toBe(false);
  });

  it('rejects a vault DELETE request unless the exact phrase is supplied', async () => {
    const response = await deleteVault(new Request('http://localhost/api/vault', { method: 'DELETE', body: JSON.stringify({ confirmation: 'DELETE MY VAULT ' }), headers: { 'content-type': 'application/json' } }));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: { code: 'confirmation_required', message: 'Type DELETE MY VAULT exactly to remove this local vault.' } });
  });

  it('forwards altered and incomplete typed confirmations unchanged instead of replacing them with a hard-coded phrase', async () => {
    const requests: RequestInit[] = [];
    const requestClient = async (input: string, init: RequestInit) => {
      expect(input).toMatch(/^\/api\/(documents\/doc-safe|vault)$/);
      requests.push(init);
      return new Response(null, { status: 204 });
    };

    await requestDocumentRemoval(requestClient, 'doc-safe', 'DELETE DOCUMENT ');
    await requestVaultRemoval(requestClient, 'DELETE');

    expect(JSON.parse(requests[0].body as string)).toEqual({ confirmation: 'DELETE DOCUMENT ' });
    expect(JSON.parse(requests[1].body as string)).toEqual({ confirmation: 'DELETE' });
  });

  it('renders the privacy page dynamically so a full refresh observes a deleted vault', () => {
    expect(privacyPageRendering).toBe('force-dynamic');
  });
});
