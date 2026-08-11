import { existsSync, lstatSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, dirname, isAbsolute, relative, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';

export type StoredFile = { documentId: string; originalName: string; safeFileName: string; relativePath: string; byteLength: number };

const safeName = (name: string) => {
  const normalized = basename(name).normalize('NFKD').replace(/[^a-zA-Z0-9._-]+/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '');
  return normalized || 'document.bin';
};

export class DocumentStorage {
  private readonly root: string;

  constructor(vaultRoot = resolve(process.cwd(), 'data/vault'), private readonly createId: () => string = randomUUID) {
    this.root = resolve(vaultRoot);
  }

  save(input: { originalName: string; bytes: Uint8Array }): StoredFile {
    const documentId = this.createId();
    const safeFileName = safeName(input.originalName);
    const relativePath = `${documentId}/${safeFileName}`;
    mkdirSync(this.root, { recursive: true });
    const target = this.resolveWithinVault(relativePath);
    mkdirSync(dirname(target), { recursive: true });
    this.resolveWithinVault(relativePath);
    writeFileSync(target, input.bytes);
    return { documentId, originalName: input.originalName, safeFileName, relativePath, byteLength: input.bytes.byteLength };
  }

  read(relativePath: string): Uint8Array {
    return new Uint8Array(readFileSync(this.resolveWithinVault(relativePath)));
  }

  private resolveWithinVault(relativePath: string): string {
    if (!relativePath || relativePath.includes('\0')) throw new Error('Vault path is invalid');
    if (isAbsolute(relativePath)) throw new Error('Vault path must be relative');
    const candidate = resolve(this.root, relativePath);
    const pathFromRoot = relative(this.root, candidate);
    if (pathFromRoot === '' || pathFromRoot.startsWith('..') || pathFromRoot.includes('../')) throw new Error('Vault path must stay within the vault root');
    this.assertNoSymlinks(pathFromRoot);
    return candidate;
  }

  private assertNoSymlinks(pathFromRoot: string): void {
    const components = [this.root, ...pathFromRoot.split('/').filter(Boolean)];
    let current = components[0];
    if (existsSync(current) && lstatSync(current).isSymbolicLink()) throw new Error('Vault path cannot contain a symlink');
    for (const component of components.slice(1)) {
      current = resolve(current, component);
      if (existsSync(current) && lstatSync(current).isSymbolicLink()) throw new Error('Vault path cannot contain a symlink');
    }
  }
}
