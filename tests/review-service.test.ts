import { describe, expect, it } from 'vitest';
import { createDatabase } from '@/data/db';
import { DocumentRepository } from '@/data/repository';
import { ReviewService } from '@/services/review-service';

describe('ReviewService', () => {
  it('corrects a pending field while retaining its cited page and source text', () => {
    const repository = new DocumentRepository(createDatabase());
    repository.savePerson({ id: 'person-sana', displayName: 'Sana Rowan', relationship: 'sibling', initials: 'SR' });
    repository.saveUpload({
      id: 'document-id', personId: 'person-sana', title: 'Sana ID (Synthetic)', category: 'identity', fileName: 'sana-id.md', storagePath: 'document-id/sana-id.md', mimeType: 'text/markdown', pageCount: 2, status: 'review',
    }, [{ id: 'field-expiry', pageNumber: 2, fieldKey: 'expires_on', label: 'Expiry date', value: '2028-04-13', confidence: 0.62, sourceText: 'Expiry date: 2028-04-13', reviewStatus: 'pending' }]);
    const review = repository.listReviewItems()[0];

    expect(review).toMatchObject({ pageNumber: 2, sourceText: 'Expiry date: 2028-04-13' });

    const result = new ReviewService(repository).resolve(review.id, { action: 'correct', value: '2028-04-18' });

    expect(result).toMatchObject({
      id: 'field-expiry', value: '2028-04-18', reviewStatus: 'corrected', pageNumber: 2, sourceText: 'Expiry date: 2028-04-13',
    });
    expect(repository.listReviewItems()).toEqual([]);
  });

  it.each([
    { action: 'accept' as const, expected: 'accepted' },
    { action: 'dismiss' as const, expected: 'dismissed' },
  ])('marks a pending field $expected when $action is chosen', ({ action, expected }) => {
    const repository = new DocumentRepository(createDatabase());
    repository.savePerson({ id: 'person-ali', displayName: 'Ali Rowan', relationship: 'self', initials: 'AR' });
    repository.saveUpload({
      id: 'document-insurance', personId: 'person-ali', title: 'Ali Insurance (Synthetic)', category: 'insurance', fileName: 'ali.md', storagePath: 'document-insurance/ali.md', mimeType: 'text/markdown', pageCount: 1, status: 'review',
    }, [{ id: 'field-policy', pageNumber: 1, fieldKey: 'policy_number', label: 'Policy number', value: 'SYN-01', confidence: 0.6, sourceText: 'Policy number: SYN-01', reviewStatus: 'pending' }]);

    const result = new ReviewService(repository).resolve(repository.listReviewItems()[0].id, { action });

    expect(result).toMatchObject({ id: 'field-policy', reviewStatus: expected });
    expect(repository.listReviewItems()).toEqual([]);
  });
});
