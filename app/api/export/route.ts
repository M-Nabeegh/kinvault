import { demoRepository } from '@/services/demo-vault';
import { DocumentStorage } from '@/services/document-storage';
import { VaultControls } from '@/services/vault-controls';

export function GET(): Response {
  const archive = new VaultControls(demoRepository(), new DocumentStorage()).createExport();
  return new Response(archive, { headers: { 'content-disposition': 'attachment; filename="kinvault-local-export.zip"', 'content-type': 'application/zip' } });
}
