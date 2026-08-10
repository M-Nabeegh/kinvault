import { basename } from 'node:path';
import type { DocumentDetail, DocumentRepository } from '@/data/repository';
import { safeDocumentDetail } from '@/services/document-response';
import type { DocumentStorage } from '@/services/document-storage';

export const VAULT_DELETE_CONFIRMATION = 'DELETE MY VAULT';
export const DOCUMENT_DELETE_CONFIRMATION = 'DELETE DOCUMENT';

type CentralDirectoryEntry = { name: Uint8Array; checksum: number; byteLength: number; offset: number; flags: number };

function updateCrc32(value: number, bytes: Uint8Array): number {
  for (const byte of bytes) {
    value ^= byte;
    for (let bit = 0; bit < 8; bit += 1) value = (value >>> 1) ^ (value & 1 ? 0xedb88320 : 0);
  }
  return value;
}

function crc32(bytes: Uint8Array): number {
  return (updateCrc32(0xffffffff, bytes) ^ 0xffffffff) >>> 0;
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

function assertZip32(value: number, label: string): void {
  if (!Number.isSafeInteger(value) || value < 0 || value > 0xffffffff) throw new Error(`${label} exceeds the ZIP32 export limit`);
}

function localHeader(name: Uint8Array, checksum: number, byteLength: number, flags: number): Uint8Array {
  assertZip32(byteLength, 'File size');
  return concatenate([uint32(0x04034b50), uint16(20), uint16(flags), uint16(0), uint16(0), uint16(0), uint32(checksum), uint32(byteLength), uint32(byteLength), uint16(name.byteLength), uint16(0), name]);
}

function centralHeader(entry: CentralDirectoryEntry): Uint8Array {
  assertZip32(entry.offset, 'Archive offset');
  return concatenate([uint32(0x02014b50), uint16(20), uint16(20), uint16(entry.flags), uint16(0), uint16(0), uint16(0), uint32(entry.checksum), uint32(entry.byteLength), uint32(entry.byteLength), uint16(entry.name.byteLength), uint16(0), uint16(0), uint16(0), uint16(0), uint32(0), uint32(entry.offset), entry.name]);
}

function dataDescriptor(checksum: number, byteLength: number): Uint8Array {
  assertZip32(byteLength, 'File size');
  return concatenate([uint32(0x08074b50), uint32(checksum), uint32(byteLength), uint32(byteLength)]);
}

function readableFrom(generator: AsyncGenerator<Uint8Array>): ReadableStream<Uint8Array> {
  return new ReadableStream({
    async pull(controller) {
      try {
        const next = await generator.next();
        if (next.done) controller.close();
        else controller.enqueue(next.value);
      } catch (caught) {
        controller.error(caught);
      }
    },
    async cancel() {
      await generator.return(undefined);
    },
  });
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

  createExportStream(): ReadableStream<Uint8Array> {
    const documents = this.repository.listDocuments().map((document) => this.repository.getDocument(document.id)!).filter(Boolean);
    const metadata = new TextEncoder().encode(`${JSON.stringify(exportMetadata(documents, this.repository), null, 2)}\n`);
    return readableFrom(this.zipChunks(documents, metadata));
  }

  private async *zipChunks(documents: DocumentDetail[], metadata: Uint8Array): AsyncGenerator<Uint8Array> {
    const encoder = new TextEncoder();
    const central: CentralDirectoryEntry[] = [];
    let offset = 0;
    const metadataName = encoder.encode('metadata.json');
    const metadataChecksum = crc32(metadata);
    const metadataHeader = localHeader(metadataName, metadataChecksum, metadata.byteLength, 0);
    yield metadataHeader;
    yield metadata;
    central.push({ name: metadataName, checksum: metadataChecksum, byteLength: metadata.byteLength, offset, flags: 0 });
    offset += metadataHeader.byteLength + metadata.byteLength;

    for (const document of documents) {
      const name = encoder.encode(`files/${document.id}/${basename(document.fileName)}`);
      const entryOffset = offset;
      const header = localHeader(name, 0, 0, 0x0008);
      yield header;
      offset += header.byteLength;

      let checksum = 0xffffffff;
      let byteLength = 0;
      for await (const chunk of this.storage.stream(document.storagePath)) {
        const bytes = new Uint8Array(chunk);
        byteLength += bytes.byteLength;
        assertZip32(byteLength, 'File size');
        checksum = updateCrc32(checksum, bytes);
        yield bytes;
        offset += bytes.byteLength;
      }
      checksum = (checksum ^ 0xffffffff) >>> 0;
      const descriptor = dataDescriptor(checksum, byteLength);
      yield descriptor;
      offset += descriptor.byteLength;
      central.push({ name, checksum, byteLength, offset: entryOffset, flags: 0x0008 });
    }

    if (central.length > 0xffff) throw new Error('Too many files for the ZIP32 export limit');
    const centralStart = offset;
    for (const entry of central) {
      const header = centralHeader(entry);
      yield header;
      offset += header.byteLength;
    }
    const centralLength = offset - centralStart;
    assertZip32(centralStart, 'Central directory offset');
    assertZip32(centralLength, 'Central directory size');
    yield concatenate([uint32(0x06054b50), uint16(0), uint16(0), uint16(central.length), uint16(central.length), uint32(centralLength), uint32(centralStart), uint16(0)]);
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
