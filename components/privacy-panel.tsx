'use client';

import { useState } from 'react';
import type { DocumentSummary } from '@/data/repository';
import { ConfirmDialog } from './confirm-dialog';
import { EmptyState } from './empty-state';
import { requestDocumentRemoval, requestVaultRemoval } from '@/services/privacy-requests';

const documentPhrase = 'DELETE DOCUMENT';
const vaultPhrase = 'DELETE MY VAULT';

async function responseError(response: Response): Promise<string> {
  const body = await response.json().catch(() => undefined) as { error?: { message?: string } } | undefined;
  return body?.error?.message ?? 'The local change could not be completed.';
}

export function PrivacyPanel({ documents: initialDocuments }: { documents: DocumentSummary[] }) {
  const [documents, setDocuments] = useState(initialDocuments);
  const [documentToDelete, setDocumentToDelete] = useState<DocumentSummary | null>(null);
  const [vaultDialogOpen, setVaultDialogOpen] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function deleteDocument(confirmation: string) {
    if (!documentToDelete) return;
    const response = await requestDocumentRemoval(fetch, documentToDelete.id, confirmation);
    if (!response.ok) { setMessage(await responseError(response)); return; }
    setDocuments((current) => current.filter((document) => document.id !== documentToDelete.id));
    setMessage(`${documentToDelete.title} and its extracted fields were removed from this local vault.`);
    setDocumentToDelete(null);
  }

  async function deleteVault(confirmation: string) {
    const response = await requestVaultRemoval(fetch, confirmation);
    if (!response.ok) { setMessage(await responseError(response)); return; }
    setDocuments([]);
    setVaultDialogOpen(false);
    setMessage('The local vault metadata and stored files were removed. This demo does not keep a recovery copy.');
  }

  return (
    <section aria-labelledby="privacy-heading" className="privacy-panel">
      <header className="privacy-panel__header">
        <div>
          <p className="eyebrow">Privacy controls</p>
          <h1 id="privacy-heading">Your local cabinet, on your terms.</h1>
          <p>KinVault stores this demo&apos;s metadata and originals only on the machine running it. Export and removal actions stay local and are never sent to an external service.</p>
        </div>
      </header>

      {message && <p className="inline-message privacy-panel__message" role="status">{message}</p>}

      <div className="privacy-panel__grid">
        <article className="privacy-card">
          <p className="eyebrow">Local boundary</p>
          <h2>No remote services, external OCR, or analytics by default.</h2>
          <p>The bundled walkthrough contains fictional records only. A production deployment still needs operating-system access controls, encrypted backups, and an independent security review.</p>
        </article>
        <article className="privacy-card">
          <p className="eyebrow">Portable copy</p>
          <h2>Export your local archive.</h2>
          <p>Download a ZIP containing safe metadata, field provenance, and the files currently stored below this vault root. Storage paths are never included in the manifest.</p>
          <a className="secondary-button" href="/api/export">Download local ZIP</a>
        </article>
      </div>

      <section aria-labelledby="document-removal-heading" className="privacy-card privacy-card--wide">
        <div className="panel-heading">
          <div><p className="eyebrow">Document removal</p><h2 id="document-removal-heading">Remove one record</h2></div>
          <span className="panel-heading__count">{documents.length} local records</span>
        </div>
        <p>Removing a document permanently removes its indexed metadata, extracted fields, and the matching local file. Confirm each removal by typing the shown phrase.</p>
        {documents.length ? <ul className="privacy-document-list">
          {documents.map((document) => <li key={document.id}><div><strong>{document.title}</strong><span>{document.personName} · {document.category}</span></div><button className="danger-button danger-button--quiet" onClick={() => setDocumentToDelete(document)} type="button">Remove document</button></li>)}
        </ul> : <EmptyState title="No local documents remain">Upload a synthetic text fixture to create a new local record.</EmptyState>}
      </section>

      <section className="privacy-card privacy-card--danger" aria-labelledby="vault-removal-heading">
        <p className="eyebrow">Irreversible local action</p>
        <h2 id="vault-removal-heading">Delete this vault</h2>
        <p>This removes all vault metadata and all files within the configured vault root. It cannot remove files outside that root, and the demo does not provide an undo or backup.</p>
        <button className="danger-button" onClick={() => setVaultDialogOpen(true)} type="button">Delete local vault</button>
      </section>

      <ConfirmDialog confirmLabel="Remove document" description={documentToDelete ? `This removes ${documentToDelete.title}, its extracted fields, and its matching local file. This cannot be undone in the demo.` : ''} onCancel={() => setDocumentToDelete(null)} onConfirm={deleteDocument} open={Boolean(documentToDelete)} requiredPhrase={documentPhrase} title="Remove this document?" />
      <ConfirmDialog confirmLabel="Delete local vault" description="This removes every metadata record and every stored file under the configured vault root. It does not delete anything outside that local root, and it cannot be undone." onCancel={() => setVaultDialogOpen(false)} onConfirm={deleteVault} open={vaultDialogOpen} requiredPhrase={vaultPhrase} title="Delete the entire local vault?" />
    </section>
  );
}
