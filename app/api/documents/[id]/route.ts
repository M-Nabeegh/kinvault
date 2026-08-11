import { NextResponse } from 'next/server';
import { demoRepository } from '@/services/demo-vault';
import { safeDocumentDetail } from '@/services/document-response';

export async function GET(_request: Request, context: { params: Promise<{ id: string }> }): Promise<NextResponse> {
  const { id } = await context.params;
  const document = demoRepository().getDocument(id);
  if (!document) return NextResponse.json({ error: { code: 'not_found', message: 'Document not found.' } }, { status: 404 });
  return NextResponse.json(safeDocumentDetail(document));
}
