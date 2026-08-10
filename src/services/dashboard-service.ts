import type { DashboardSnapshot } from '@/data/repository';
import type { DocumentRepository } from '@/data/repository';

export class DashboardService {
  constructor(private readonly repository: DocumentRepository) {}

  snapshot(now = new Date().toISOString()): DashboardSnapshot {
    const snapshot = this.repository.listDashboard();
    const today = now.slice(0, 10);
    const nextExpiry = this.repository.listDocuments()
      .filter((document) => document.expiresOn && document.expiresOn >= today)
      .sort((left, right) => left.expiresOn!.localeCompare(right.expiresOn!))[0] ?? null;
    return { ...snapshot, nextExpiry };
  }
}
