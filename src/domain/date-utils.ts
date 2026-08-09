const CALENDAR_DATE = /^(\d{4})-(\d{2})-(\d{2})/;
const MILLISECONDS_PER_DAY = 86_400_000;

function calendarTimestamp(value: string): number {
  const match = CALENDAR_DATE.exec(value);

  if (!match) {
    throw new Error(`Expected an ISO calendar date, received: ${value}`);
  }

  const [, year, month, day] = match;
  const timestamp = Date.UTC(Number(year), Number(month) - 1, Number(day));
  const parsed = new Date(timestamp);

  if (
    parsed.getUTCFullYear() !== Number(year) ||
    parsed.getUTCMonth() !== Number(month) - 1 ||
    parsed.getUTCDate() !== Number(day)
  ) {
    throw new Error(`Expected a valid ISO calendar date, received: ${value}`);
  }

  return timestamp;
}

export function daysUntil(date: string, today = new Date().toISOString()): number {
  return (calendarTimestamp(date) - calendarTimestamp(today)) / MILLISECONDS_PER_DAY;
}

export function documentsExpiringBetween(dates: string[], start: string, end: string): string[] {
  const startTimestamp = calendarTimestamp(start);
  const endTimestamp = calendarTimestamp(end);

  if (startTimestamp > endTimestamp) {
    throw new Error('Expiry window start must be on or before its end');
  }

  return dates.filter((date) => {
    const timestamp = calendarTimestamp(date);
    return timestamp >= startTimestamp && timestamp <= endTimestamp;
  });
}
