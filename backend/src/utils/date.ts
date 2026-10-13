export const BUSINESS_TIME_ZONE = 'Asia/Riyadh';

export type BusinessDateParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
};

export function businessDateParts(value: Date): BusinessDateParts {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: BUSINESS_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(value);
  const part = (type: Intl.DateTimeFormatPartTypes): number => {
    const raw = parts.find((entry) => entry.type === type)?.value;
    if (raw === undefined) throw new Error(`Missing ${type} in business date`);
    return Number(raw);
  };
  return {
    year: part('year'),
    month: part('month'),
    day: part('day'),
    hour: part('hour'),
    minute: part('minute'),
  };
}

/** Convert an instant to the PostgreSQL DATE for the Riyadh business day. */
export function dateOnly(value: Date): Date {
  const { year, month, day } = businessDateParts(value);
  return new Date(Date.UTC(year, month - 1, day));
}

export function todayDate(): Date {
  return dateOnly(new Date());
}

export function isPastBusinessTime(cutoff: string, value: Date): boolean {
  const [cutoffHour, cutoffMinute] = cutoff.split(':').map(Number);
  const { hour, minute } = businessDateParts(value);
  return hour * 60 + minute >= cutoffHour * 60 + cutoffMinute;
}

export function addBusinessDays(value: Date, days: number): Date {
  const date = dateOnly(value);
  date.setUTCDate(date.getUTCDate() + days);
  return date;
}

/** Converts a Riyadh wall-clock time on a DATE value to an absolute instant. */
export function riyadhTimeOnDate(date: Date, hour: number, minute = 0): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), hour - 3, minute),
  );
}

export function attendanceOperationalDate(direction: 'OUTBOUND' | 'RETURN', now: Date): Date {
  if (direction === 'RETURN') return dateOnly(now);
  const { hour } = businessDateParts(now);
  return hour >= 18 ? addBusinessDays(now, 1) : dateOnly(now);
}

export function attendanceOpensAt(direction: 'OUTBOUND' | 'RETURN', operationalDate: Date): Date {
  return direction === 'OUTBOUND'
    ? riyadhTimeOnDate(addBusinessDays(operationalDate, -1), 18)
    : riyadhTimeOnDate(operationalDate, 11);
}
