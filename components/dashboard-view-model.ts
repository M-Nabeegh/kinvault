import type { DashboardSnapshot } from '@/data/repository';

export type DashboardExpiryCopy = {
  count: number;
  message: string;
  tone: 'quiet' | 'attention' | 'scheduled';
};

function calendarDaysBetween(start: string, end: string): number {
  const startDay = new Date(`${start.slice(0, 10)}T00:00:00.000Z`).getTime();
  const endDay = new Date(`${end.slice(0, 10)}T00:00:00.000Z`).getTime();
  return Math.round((endDay - startDay) / 86_400_000);
}

export function dashboardExpiryCopy(snapshot: DashboardSnapshot, today: string): DashboardExpiryCopy {
  if (!snapshot.nextExpiry?.expiresOn) {
    return { count: 0, message: 'No expiry dates yet', tone: 'quiet' };
  }

  const daysUntilExpiry = calendarDaysBetween(today, snapshot.nextExpiry.expiresOn);
  if (daysUntilExpiry >= 0 && daysUntilExpiry <= 90) {
    return { count: 1, message: '1 document expires within 90 days', tone: 'attention' };
  }

  return { count: 1, message: '1 upcoming expiry date', tone: 'scheduled' };
}
