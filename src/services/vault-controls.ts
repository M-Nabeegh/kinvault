import { basename } from 'node:path';
import type { DocumentDetail, DocumentRepository } from '@/data/repository';
import { safeDocumentDetail } from '@/services/document-response';
import type { DocumentStorage } from '@/services/document-storage';

export const VAULT_DELETE_CONFIRMATION = 'DELETE MY VAULT';
export const DOCUMENT_DELETE_CONFIRMATION = 'DELETE DOCUMENT';

type ExportEntry = { name: string; bytes: Uint8Array };

function crc32(bytes: Uint8Array): number {
  let value = 0xffffffff;
  for (const byte of bytes) {
    value ^= byte;
    for (let bit = 0; bit < 8; bit += 1) value = (value >>> 1) ^ (value & 1 ? 0xedb88320 : 0);
  }
  return (value ^ 0xffffffff) >>> 0;
}

function uint16(value: number): Uint8Array {
  const bytes = new Uint8Array(2);
  new DataView(bytes.buffer).setUint16(0, value, true);
  return bytes;
}

function uint32(value: number): Uint8Array {
  const bytes = new Uint8Array(4);
  new DataView(bytes.buffer).setUint32(0, value >>> 0, true);
  return bytes;
}

function concatenate(parts: Uint8Array[]): Uint8Array {
  const result = new Uint8Array(parts.reduce((total, part) => total + part.byteLength, 0));
  let offset = 0;
  for (const part of parts) { result.set(part, offset); offset += part.byteLength; }
  return result;
}

/** Creates a standards-compatible, uncompressed ZIP so export never needs a remote service. */
function createLocalZip(entries: ExportEntry[]): Uint8Array {
  const encoder = new TextEncoder();
  const local: Uint8Array[] = [];
  const central: Uint8Array[] = [];
  let offset = 0;
  for (const entry of entries) {
    const name = encoder.encode(entry.name);
    const checksum = crc32(entry.bytes);
    const header = concatenate([uint32(0x04034b50), uint16(20), uint16(0), uint16(0), uint16(0), uint16(0), uint32(checksum), uint32(entry.bytes.byteLength), uint32(entry.bytes.byteLength), uint16(name.byteLength), uint16(0), name]);
    local.push(header, entry.bytes);
    central.push(concatenate([uint32(0x02014b50), uint16(20), uint16(20), uint16(0), uint16(0), uint16(0), uint16(0), uint32(checksum), uint32(entry.bytes.byteLength), uint32(entry.bytes.byteLength), uint16(name.byteLength), uint16(0), uint16(0), uint16(0), uint16(0), uint32(0), uint32(offset), name]));
    offset += header.byteLength + entry.bytes.byteLength;
  }
  const centralDirectory = concatenate(central);
  return concatenate([...local, centralDirectory, uint32(0x06054b50), uint16(0), uint16(0), uint16(entries.length), uint16(entries.length), uint32(centralDirectory.byteLength), uint32(offset), uint16(0)]);
}

function exportMetadata(documents: DocumentDetail[], repository: DocumentRepository) {
  return {
    format: 'kinvault-export-v1',
    exportedAt: new Date().toISOString(),
    dataClassification: 'synthetic-demo-data',
    people: repository.listPeople(),
    documents: documents.map((document) => safeDocumentDetail(document)),
  };
}

export class VaultControls {
  constructor(private readonly repository: DocumentRepository, private readonly storage: DocumentStorage) {}

  createExport(): Uint8Array {
    const documents = this.repository.listDocuments().map((document) => this.repository.getDocument(document.id)!).filter(Boolean);
    const metadata = new TextEncoder().encode(`${JSON.stringify(exportMetadata(documents, this.repository), null, 2)}\n`);
    const files = documents.map((document) => ({ name: `files/${document.id}/${basename(document.fileName)}`, bytes: this.storage.read(document.storagePath) }));
    return createLocalZip([{ name: 'metadata.json', bytes: metadata }, ...files]);
  }

  deleteDocument(id: string, confirmation: string): { deleted: boolean; documentId: string } {
    if (confirmation !== DOCUMENT_DELETE_CONFIRMATION) return { deleted: false, documentId: id };
    const document = this.repository.getDocument(id);
    if (!document) return { deleted: false, documentId: id };
    this.storage.delete(document.storagePath);
    this.repository.deleteDocument(id);
    return { deleted: true, documentId: id };
  }

  deleteVault(confirmation: string): { deleted: true; documentCount: number } | { deleted: false; reason: 'confirmation_required' } {
    if (confirmation !== VAULT_DELETE_CONFIRMATION) return { deleted: false, reason: 'confirmation_required' };
    const documentCount = this.repository.listDocuments().length;
    this.storage.deleteVault();
    this.repository.deleteVaultMetadata();
    return { deleted: true, documentCount };
  }
}
