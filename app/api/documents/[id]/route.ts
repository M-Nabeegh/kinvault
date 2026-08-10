import { NextResponse } from 'next/server';
import { demoRepository } from '@/services/demo-vault';
import { safeDocumentDetail } from '@/services/document-response';
import { DocumentStorage } from '@/services/document-storage';
import { DOCUMENT_DELETE_CONFIRMATION, VaultControls } from '@/services/vault-controls';

export async function GET(_request: Request, context: { params: Promise<{ id: string }> }): Promise<NextResponse> {
  const { id } = await context.params;
  const document = demoRepository().getDocument(id);
  if (!document) return NextResponse.json({ error: { code: 'not_found', message: 'Document not found.' } }, { status: 404 });
  return NextResponse.json(safeDocumentDetail(document));
}

export async function DELETE(request: Request, context: { params: Promise<{ id: string }> }): Promise<NextResponse> {
  const { id } = await context.params;
  let confirmation: unknown;
  try { confirmation = (await request.json()).confirmation; } catch { confirmation = undefined; }
  if (confirmation !== DOCUMENT_DELETE_CONFIRMATION) return NextResponse.json({ error: { code: 'confirmation_required', message: 'Confirm document removal before deleting local data.' } }, { status: 400 });
  const result = new VaultControls(demoRepository(), new DocumentStorage()).deleteDocument(id, confirmation);
  if (!result.deleted) return NextResponse.json({ error: { code: 'not_found', message: 'Document not found.' } }, { status: 404 });
  return NextResponse.json(result);
}
