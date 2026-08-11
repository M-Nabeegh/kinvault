import { describe, expect, it } from 'vitest';
import type { DashboardSnapshot } from '@/data/repository';
import { dashboardExpiryCopy } from '../components/dashboard-view-model';

const emptySnapshot: DashboardSnapshot = {
  documentCount: 0,
  categoryCounts: [],
  nextExpiry: null,
  reviewCount: 0,
  recentDocuments: [],
};

describe('dashboard expiry copy', () => {
  it('guides an empty vault when no expiry date is indexed', () => {
    expect(dashboardExpiryCopy(emptySnapshot, '2026-08-11')).toEqual({
      count: 0,
      message: 'No expiry dates yet',
      tone: 'quiet',
    });
  });

  it('calls out the count when an indexed document expires within 90 days', () => {
    const snapshot: DashboardSnapshot = {
      ...emptySnapshot,
      documentCount: 1,
      nextExpiry: {
        id: 'demo-dad-passport',
        personId: 'demo-dad',
        personName: 'Dad Rowan',
        title: 'Dad Passport (Synthetic)',
        category: 'passport',
        status: 'indexed',
        expiresOn: '2026-11-09',
        createdAt: '2026-08-11T00:00:00.000Z',
      },
    };

    expect(dashboardExpiryCopy(snapshot, '2026-08-11')).toEqual({
      count: 1,
      message: '1 document expires within 90 days',
      tone: 'attention',
    });
  });
});
