import { isPaymentCardContent } from '@/domain/sensitive-data-policy';
import type { DocumentDetail, DocumentRepository, NewDocumentInput } from '@/data/repository';
import type { DocumentStorage } from './document-storage';
import type { ExtractionService } from './extraction-service';

const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;
const allowedMimeTypes = new Set(['text/plain', 'text/markdown', 'text/csv']);

export type IngestInput = Omit<NewDocumentInput, 'id' | 'storagePath' | 'fileName' | 'pageCount'> & {
  originalName: string;
  mimeType: string;
  bytes: Uint8Array;
  textHint?: string;
};
export type IngestResult =
  | { status: 'accepted'; document: DocumentDetail }
  | { status: 'rejected'; code: 'invalid_mime' | 'file_too_large' | 'sensitive_data'; message: string };

export class IngestService {
  constructor(private readonly repository: DocumentRepository, private readonly storage: DocumentStorage, private readonly extractor: ExtractionService) {}

  async ingest(input: IngestInput): Promise<IngestResult> {
    if (!allowedMimeTypes.has(input.mimeType)) return { status: 'rejected', code: 'invalid_mime', message: 'Only synthetic plain text, Markdown, and CSV files can be indexed.' };
    if (input.bytes.byteLength > MAX_UPLOAD_BYTES) return { status: 'rejected', code: 'file_too_large', message: 'Files must be 10 MB or smaller.' };

    const extractedText = new TextDecoder().decode(input.bytes);
    const policy = isPaymentCardContent({ fileName: input.originalName, category: input.category, extractedText });
    if (policy.blocked) return { status: 'rejected', code: 'sensitive_data', message: policy.reason! };

    const storedFile = this.storage.save({ originalName: input.originalName, bytes: input.bytes });
    const extraction = await this.extractor.extract({ storedFile, textHint: extractedText });
    const document = this.repository.saveUpload({ ...input, id: storedFile.documentId, fileName: storedFile.safeFileName, storagePath: storedFile.relativePath, pageCount: extraction.pageCount, status: extraction.fields.some((field) => field.confidence < 0.75) ? 'review' : 'indexed' }, extraction.fields);
    return { status: 'accepted', document };
  }
}
