import type { ExtractedField, DocumentRepository, ReviewResolution } from '@/data/repository';

export class ReviewService {
  constructor(private readonly repository: DocumentRepository) {}

  resolve(reviewId: string, resolution: ReviewResolution): ExtractedField | null {
    return this.repository.resolveReviewItem(reviewId, resolution);
  }
}
