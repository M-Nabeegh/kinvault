import { z } from 'zod';
import { NextResponse } from 'next/server';
import { type DocumentCategory, type DocumentStatus } from '@/data/repository';
import { demoRepository } from '@/services/demo-vault';
import { IngestService } from '@/services/ingest-service';
import { DeterministicExtractionService } from '@/services/extraction-service';
import { DocumentStorage } from '@/services/document-storage';
import { safeDocumentDetail } from '@/services/document-response';

const categories = ['passport', 'identity', 'insurance', 'school', 'vehicle', 'visa', 'certificate', 'utility'] as const;
const statuses = ['indexed', 'review', 'rejected'] as const;
const mimeTypes = new Set(['text/plain', 'text/markdown', 'text/csv']);
const maxUploadBytes = 10 * 1024 * 1024;
const uploadSchema = z.object({
  personId: z.string().trim().min(1).max(120),
  category: z.enum(categories),
  title: z.string().trim().min(1).max(160),
});

function error(code: string, message: string, status: number): NextResponse {
  return NextResponse.json({ error: { code, message } }, { status });
}

export function GET(request: Request): NextResponse {
  const search = new URL(request.url).searchParams;
  const category = search.get('category');
  const status = search.get('status');
  const personId = search.get('person');
  if (category && !categories.includes(category as DocumentCategory)) return error('invalid_category', 'Choose a valid document category.', 400);
  if (status && !statuses.includes(status as DocumentStatus)) return error('invalid_status', 'Choose a valid document status.', 400);

  return NextResponse.json({ documents: demoRepository().listDocuments({ personId: personId || undefined, category: category as DocumentCategory | undefined, status: status as DocumentStatus | undefined }) });
}

export async function POST(request: Request): Promise<NextResponse> {
  const formData = await request.formData();
  const file = formData.get('file');
  const parsed = uploadSchema.safeParse({ personId: formData.get('personId'), category: formData.get('category'), title: formData.get('title') });
  if (!parsed.success) return error('invalid_upload', 'Choose a person, category, and title for this document.', 400);
  if (!(file instanceof File)) return error('missing_file', 'Choose a synthetic text file to upload.', 400);
  if (!mimeTypes.has(file.type)) return error('invalid_mime', 'Only synthetic plain text, Markdown, and CSV files can be indexed.', 400);
  if (file.size > maxUploadBytes) return error('file_too_large', 'Files must be 10 MB or smaller.', 400);

  const repository = demoRepository();
  if (!repository.hasPerson(parsed.data.personId)) return error('invalid_person', 'Choose a person already in this vault.', 400);

  const bytes = new Uint8Array(await file.arrayBuffer());
  const result = await new IngestService(repository, new DocumentStorage(), new DeterministicExtractionService()).ingest({ ...parsed.data, originalName: file.name, mimeType: file.type, bytes });
  if (result.status === 'rejected') return error(result.code, result.message, result.code === 'sensitive_data' ? 422 : 400);
  return NextResponse.json(safeDocumentDetail(result.document), { status: 201 });
}
