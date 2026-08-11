import { existsSync, lstatSync, mkdirSync, readFileSync, rmSync, rmdirSync, unlinkSync, writeFileSync } from 'node:fs';
import { basename, dirname, isAbsolute, relative, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';

export type StoredFile = { documentId: string; originalName: string; safeFileName: string; relativePath: string; byteLength: number };

const safeName = (name: string) => {
  const normalized = basename(name).normalize('NFKD').replace(/[^a-zA-Z0-9._-]+/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '');
  return normalized || 'document.bin';
};

export class DocumentStorage {
  private readonly root: string;

  constructor(vaultRoot = process.env.KINVAULT_VAULT_ROOT ?? resolve(process.cwd(), 'data/vault'), private readonly createId: () => string = randomUUID) {
    this.root = resolve(vaultRoot);
    const workspace = resolve(process.cwd());
    if (this.root === workspace || !relative(this.root, workspace).startsWith('..')) throw new Error('Vault root must not contain the application workspace');
  }

  save(input: { originalName: string; bytes: Uint8Array }): StoredFile {
    const documentId = this.createId();
    const safeFileName = safeName(input.originalName);
    const relativePath = `${documentId}/${safeFileName}`;
    this.write(relativePath, input.bytes);
    return { documentId, originalName: input.originalName, safeFileName, relativePath, byteLength: input.bytes.byteLength };
  }

  read(relativePath: string): Uint8Array {
    return new Uint8Array(readFileSync(this.resolveWithinVault(relativePath)));
  }

  exists(relativePath: string): boolean {
    return existsSync(this.resolveWithinVault(relativePath));
  }

  delete(relativePath: string): void {
    const target = this.resolveWithinVault(relativePath);
    if (!existsSync(target)) return;
    unlinkSync(target);
    const documentDirectory = dirname(target);
    if (documentDirectory !== this.root) {
      try { rmdirSync(documentDirectory); } catch { /* Leave a non-empty document directory intact. */ }
    }
  }

  deleteVault(): void {
    if (!existsSync(this.root)) return;
    if (lstatSync(this.root).isSymbolicLink()) throw new Error('Vault root cannot be a symlink');
    rmSync(this.root, { force: true, recursive: true });
  }

  write(relativePath: string, bytes: Uint8Array): void {
    mkdirSync(this.root, { recursive: true });
    const target = this.resolveWithinVault(relativePath);
    mkdirSync(dirname(target), { recursive: true });
    this.resolveWithinVault(relativePath);
    writeFileSync(target, bytes);
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
