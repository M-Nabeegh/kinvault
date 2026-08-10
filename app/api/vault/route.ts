import { NextResponse } from 'next/server';
import { demoRepository } from '@/services/demo-vault';
import { DocumentStorage } from '@/services/document-storage';
import { VAULT_DELETE_CONFIRMATION, VaultControls } from '@/services/vault-controls';

export async function DELETE(request: Request): Promise<NextResponse> {
  let confirmation: unknown;
  try { confirmation = (await request.json()).confirmation; } catch { confirmation = undefined; }
  if (confirmation !== VAULT_DELETE_CONFIRMATION) {
    return NextResponse.json({ error: { code: 'confirmation_required', message: 'Type DELETE MY VAULT exactly to remove this local vault.' } }, { status: 400 });
  }
  const result = new VaultControls(demoRepository(), new DocumentStorage()).deleteVault(confirmation);
  return NextResponse.json(result);
}
