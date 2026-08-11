export type LocalRequestClient = (input: string, init: RequestInit) => Promise<Response>;

function removalRequest(confirmation: string): RequestInit {
  return { method: 'DELETE', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ confirmation }) };
}

/** Sends exactly the phrase that the person typed; server-side routes decide whether it is valid. */
export function requestDocumentRemoval(request: LocalRequestClient, id: string, confirmation: string): Promise<Response> {
  return request(`/api/documents/${encodeURIComponent(id)}`, removalRequest(confirmation));
}

/** Sends exactly the phrase that the person typed; server-side routes decide whether it is valid. */
export function requestVaultRemoval(request: LocalRequestClient, confirmation: string): Promise<Response> {
  return request('/api/vault', removalRequest(confirmation));
}
