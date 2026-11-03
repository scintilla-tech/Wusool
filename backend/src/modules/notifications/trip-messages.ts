import type { PushPayload } from '../../providers/notifications';

/** Arabic notifications about trips, covers, absences and routes. */

type Direction = 'OUTBOUND' | 'RETURN';

const BOTH: Direction[] = ['OUTBOUND', 'RETURN'];

const directionName = (direction: Direction) =>
  direction === 'OUTBOUND' ? 'رحلة الذهاب' : 'رحلة العودة';

function tripsLine(directions: Direction[]): string {
  const sorted = [...new Set(directions)].sort();
  if (sorted.length === 2) return 'رحلتا الذهاب والعودة';
  return directionName(sorted[0] ?? 'OUTBOUND');
}

export interface BusLabel {
  plateNumber: string;
  name: string | null;
}

const busName = (bus: BusLabel) => bus.name ?? bus.plateNumber;

/**
 * A day in a sentence: `of` after a noun ("رحلات الغد"), `on` as a time
 * ("غداً").
 */
export interface DayPhrase {
  of: string;
  on: string;
}

export const TODAY: DayPhrase = { of: 'اليوم', on: 'اليوم' };

const WEEKDAYS = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const MONTHS = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/** `date` and `today` are business dates (UTC midnight). */
export function dayPhrase(date: Date, today: Date): DayPhrase {
  const days = Math.round((date.getTime() - today.getTime()) / 86_400_000);
  if (days === 0) return TODAY;
  if (days === 1) return { of: 'الغد', on: 'غداً' };
  const label = `${WEEKDAYS[date.getUTCDay()]} ${date.getUTCDate()} ${MONTHS[date.getUTCMonth()]}`;
  return { of: label, on: `يوم ${label}` };
}

/** The morning schedule created today's trips on the driver's bus. */
export function tripsReady(bus: BusLabel, routeName: string, directions: Direction[]): PushPayload {
  return {
    type: 'TRIPS_READY',
    title: 'رحلات اليوم جاهزة',
    body: `${tripsLine(directions)} على ${busName(bus)} · ${routeName}.`,
    data: { directions },
  };
}

/** The driver's bus has no fixed route, so no trip was made for it. */
export function tripNeeded(bus: BusLabel): PushPayload {
  return {
    type: 'TRIP_NEEDED',
    title: 'لا رحلة مجدولة لحافلتك اليوم',
    body: `ليس لـ${busName(bus)} مسار ثابت. أنشئ مسارها من التطبيق مرة واحدة لتُجدول رحلاتها.`,
  };
}

/** A supervisor gave this driver another driver's trips. */
export function coverAssigned(
  bus: BusLabel,
  regularDriver: string | null,
  directions: Direction[] = BOTH,
  day: DayPhrase = TODAY,
): PushPayload {
  return {
    type: 'COVER_ASSIGNED',
    title: `كُلّفت بتغطية رحلات ${day.of}`,
    body: `${tripsLine(directions)} على ${busName(bus)}${
      regularDriver ? ` بدلاً من ${regularDriver}` : ''
    }.`,
    data: { directions },
  };
}

/** Another driver covers this driver's trips. */
export function coverReplaced(
  bus: BusLabel,
  coverDriver: string,
  directions: Direction[] = BOTH,
  day: DayPhrase = TODAY,
): PushPayload {
  return {
    type: 'COVER_REPLACED',
    title: `سائق بديل لرحلاتك ${day.on}`,
    body: `${tripsLine(directions)} على ${busName(bus)} ${day.on} مع ${coverDriver}.`,
    data: { directions },
  };
}

/** The driver's trips were given back to them. */
export function coverEnded(
  bus: BusLabel,
  directions: Direction[] = BOTH,
  day: DayPhrase = TODAY,
): PushPayload {
  return {
    type: 'COVER_ENDED',
    title: `أُعيدت إليك رحلات ${day.of}`,
    body: `${tripsLine(directions)} على ${busName(bus)}.`,
    data: { directions },
  };
}

/**
 * The driver no longer covers another bus's trips: they went back to the
 * bus's own driver, or to another cover.
 */
export function coverCancelled(
  bus: BusLabel,
  directions: Direction[],
  backToRegular: boolean,
  day: DayPhrase = TODAY,
): PushPayload {
  return {
    type: 'COVER_CANCELLED',
    title: `أُلغي تكليفك برحلات ${day.of}`,
    body: `${tripsLine(directions)} على ${busName(bus)} ${
      backToRegular ? 'عادت إلى سائقها' : 'أُسندت إلى سائق آخر'
    }.`,
    data: { directions },
  };
}

/** To the bus's supervisors: its driver cannot drive on a day. */
export function driverAbsent(
  driver: string,
  bus: BusLabel,
  day: DayPhrase,
  note: string | null,
): PushPayload {
  return {
    type: 'DRIVER_ABSENT',
    title: `${driver} لن يقود ${day.on}`,
    body: `${busName(bus)}${note ? `: ${note}` : ''}. اختاري سائقاً بديلاً.`,
  };
}

/** To the bus's supervisors: the driver will drive after all. */
export function absenceCancelled(driver: string, bus: BusLabel, day: DayPhrase): PushPayload {
  return {
    type: 'ABSENCE_CANCELLED',
    title: `${driver} سيقود ${day.on}`,
    body: `أُلغي إبلاغ الغياب عن ${busName(bus)}.`,
  };
}

/** To the bus's supervisors on the morning of an absence with no cover. */
export function coverStillNeeded(driver: string, bus: BusLabel): PushPayload {
  return {
    type: 'COVER_NEEDED',
    title: 'لم يُختر سائق بديل لرحلات اليوم',
    body: `${driver} غائب اليوم عن ${busName(bus)}. اختاري سائقاً بديلاً.`,
  };
}

/** To admins: a driver built their bus's route, which needs students. */
export function routeByDriver(driver: string, routeName: string, bus: BusLabel): PushPayload {
  return {
    type: 'ROUTE_BY_DRIVER',
    title: 'مسار جديد من سائق',
    body: `أنشأ ${driver} «${routeName}» لحافلة ${busName(bus)}. أضف إليه الطالبات.`,
  };
}
