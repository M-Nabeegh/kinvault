import { describe, expect, it } from 'vitest';
import { GET as documents, POST as upload } from '../app/api/documents/route';
import { GET as document } from '../app/api/documents/[id]/route';
import { GET as review } from '../app/api/review/route';
import { PATCH as resolveReview } from '../app/api/review/[id]/route';

describe('document and review API contracts', () => {
  it('returns filtered documents and safe source metadata without a storage path', async () => {
    const listResponse = await documents(new Request('http://localhost/api/documents?category=passport'));
    const listBody = await listResponse.json();
    const detailResponse = await document(new Request('http://localhost/api/documents/demo-dad-passport'), { params: Promise.resolve({ id: 'demo-dad-passport' }) });
    const detailBody = await detailResponse.json();

    expect(listResponse.status).toBe(200);
    expect(listBody.documents).toEqual([expect.objectContaining({ id: 'demo-dad-passport', category: 'passport' })]);
    expect(detailResponse.status).toBe(200);
    expect(detailBody).toMatchObject({ id: 'demo-dad-passport', fields: [expect.objectContaining({ pageNumber: 2, sourceText: expect.stringContaining('Expiry date') })] });
    expect(detailBody).not.toHaveProperty('storagePath');
  });

  it('rejects an unsupported MIME type before indexing a multipart upload', async () => {
    const formData = new FormData();
    formData.set('personId', 'demo-ali');
    formData.set('category', 'insurance');
    formData.set('title', 'Synthetic image');
    formData.set('file', new File(['not an image'], 'synthetic.png', { type: 'image/png' }));

    const response = await upload(new Request('http://localhost/api/documents', { method: 'POST', body: formData }));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: { code: 'invalid_mime', message: 'Only synthetic plain text, Markdown, and CSV files can be indexed.' } });
  });

  it('resolves a review item through its id and removes it from the queue', async () => {
    const queue = await (await review()).json();
    const item = queue.items[0];

    const response = await resolveReview(new Request(`http://localhost/api/review/${item.id}`, { method: 'PATCH', body: JSON.stringify({ action: 'dismiss' }), headers: { 'content-type': 'application/json' } }), { params: Promise.resolve({ id: item.id }) });

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ field: { id: item.fieldId, reviewStatus: 'dismissed' } });
    await expect((await review()).json()).resolves.toEqual({ items: [] });
  });
});
