import { afterEach, describe, expect, it } from 'vitest';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DocumentStorage } from '@/services/document-storage';

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

describe('DocumentStorage', () => {
  it('rejects paths that escape the vault root', () => {
    const directory = mkdtempSync(join(tmpdir(), 'kinvault-storage-'));
    temporaryDirectories.push(directory);
    const storage = new DocumentStorage(directory);

    expect(() => storage.read('../../outside.txt')).toThrow(/vault/i);
  });

  it('saves and reads bytes at a generated vault-relative path', () => {
    const directory = mkdtempSync(join(tmpdir(), 'kinvault-storage-'));
    temporaryDirectories.push(directory);
    const storage = new DocumentStorage(directory, () => 'document-1');

    const stored = storage.save({ originalName: 'dad passport.md', bytes: new TextEncoder().encode('synthetic fixture') });

    expect(stored.relativePath).toBe('document-1/dad-passport.md');
    expect(new TextDecoder().decode(storage.read(stored.relativePath))).toBe('synthetic fixture');
  });
});
