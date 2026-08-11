import type { DocumentRepository, NewDocumentInput } from '@/data/repository';
import type { DocumentStorage } from './document-storage';
import type { ExtractionService } from './extraction-service';

export class IngestService {
  constructor(private readonly repository: DocumentRepository, private readonly storage: DocumentStorage, private readonly extractor: ExtractionService) {}

  async ingest(input: Omit<NewDocumentInput, 'id' | 'storagePath' | 'fileName' | 'pageCount'> & { originalName: string; bytes: Uint8Array; textHint?: string }) {
    const storedFile = this.storage.save({ originalName: input.originalName, bytes: input.bytes });
    const extraction = await this.extractor.extract({ storedFile, textHint: input.textHint });
    return this.repository.saveUpload({ ...input, id: storedFile.documentId, fileName: storedFile.safeFileName, storagePath: storedFile.relativePath, pageCount: extraction.pageCount }, extraction.fields);
  }
}
