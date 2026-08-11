import { describe, expect, it } from 'vitest';
import { GET as search } from '../app/api/search/route';
import { GET as dashboard } from '../app/api/dashboard/route';
import { GET as people } from '../app/api/people/route';

describe('API contracts', () => {
  it('serializes cited answer results from the search route', async () => {
    const response = await search(new Request('http://localhost/api/search?q=When%20does%20Dad%27s%20passport%20expire%3F'));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      result: {
        status: 'answered',
        citations: [{
          documentId: 'demo-dad-passport',
          documentTitle: 'Dad Passport (Synthetic)',
          page: 2,
          field: 'Expiry date',
          value: '2026-11-09',
          confidence: 0.96,
        }],
      },
      results: [expect.objectContaining({
        id: 'demo-dad-passport',
        documentId: 'demo-dad-passport',
        title: 'Dad Passport (Synthetic)',
        personName: 'Dad Rowan',
        category: 'passport',
        expiresOn: '2026-11-09',
        status: 'indexed',
      })],
    });
  });

  it('returns a stable validation envelope for an empty search query', async () => {
    const response = await search(new Request('http://localhost/api/search?q='));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: { code: 'invalid_query', message: 'Query must be between 1 and 240 characters.' } });
  });

  it('returns dashboard and people payloads with their documented envelopes', async () => {
    const [dashboardResponse, peopleResponse] = await Promise.all([
      dashboard(),
      people(),
    ]);

    expect(dashboardResponse.status).toBe(200);
    await expect(dashboardResponse.json()).resolves.toMatchObject({ documentCount: 4 });
    expect(peopleResponse.status).toBe(200);
    await expect(peopleResponse.json()).resolves.toEqual({ people: expect.arrayContaining([
      expect.objectContaining({ id: 'demo-dad', displayName: 'Dad Rowan', documentCount: 1 }),
    ]) });
  });
});
