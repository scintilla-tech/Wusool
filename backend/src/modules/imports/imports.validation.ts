import { emailSchema, nameSchema, saudiPhoneSchema } from '../../validation/common';
import {
  fieldsFor,
  idFieldFor,
  type FieldKey,
  type ImportRole,
  type PersonRow,
} from './imports.fields';

export type IssueCode =
  | 'REQUIRED'
  | 'INVALID_NAME'
  | 'INVALID_PHONE'
  | 'INVALID_EMAIL'
  | 'INVALID_DATE'
  | 'INVALID_NATIONAL_ID'
  | 'TOO_LONG'
  | 'DUPLICATE_IN_LIST'
  | 'PHONE_TAKEN'
  | 'EMAIL_TAKEN'
  | 'ID_TAKEN'
  | 'ALREADY_EXISTS';

/** A problem with one value; `field` is null when it concerns the whole row. */
export interface RowIssue {
  field: FieldKey | null;
  code: IssueCode;
}

/** A row's values once valid, in the shape the account services expect. */
export interface CleanRow {
  firstName: string;
  lastName: string;
  phone: string;
  email?: string;
  /** University number for students, employee number for staff. */
  id: string;
  nationalIdOrIqama?: string;
  nationality?: string;
  joinDate?: Date;
  iqamaExpiry?: Date;
}

const ARABIC_DIGITS = /[٠-٩۰-۹]/g;

/** Arabic-Indic and Persian digits typed in Arabic keyboards become 0-9. */
export function toAsciiDigits(value: string): string {
  return value.replace(ARABIC_DIGITS, (digit) => String(digit.charCodeAt(0) % 16));
}

const pad = (n: number) => String(n).padStart(2, '0');

/**
 * Gregorian dates as YYYY-MM-DD, or day first (DD/MM/YYYY) as written in
 * Saudi Arabia. Returns null for anything else, including Hijri years.
 */
export function normalizeDate(raw: string): string | null {
  const value = toAsciiDigits(raw).trim();
  let parts: [number, number, number] | null = null;
  const yearFirst = /^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$/.exec(value);
  const dayFirst = /^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$/.exec(value);
  if (yearFirst) parts = [Number(yearFirst[1]), Number(yearFirst[2]), Number(yearFirst[3])];
  else if (dayFirst) parts = [Number(dayFirst[3]), Number(dayFirst[2]), Number(dayFirst[1])];
  if (!parts) return null;

  const [year, month, day] = parts;
  if (year < 1900 || year > 2200) return null;
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  return `${year}-${pad(month)}-${pad(day)}`;
}

/** Saudi mobile numbers in any common spelling, as +9665XXXXXXXX. */
export function normalizePhone(raw: string): string | null {
  let value = toAsciiDigits(raw).replace(/[\s()-]/g, '');
  // Spreadsheets drop the leading zero when the column is numeric.
  if (/^5\d{8}$/.test(value)) value = `0${value}`;
  const parsed = saudiPhoneSchema.safeParse(value);
  return parsed.success ? parsed.data : null;
}

type Checked = { value: string | Date } | { issue: IssueCode };

function checkValue(type: string, raw: string): Checked {
  switch (type) {
    case 'name': {
      const parsed = nameSchema.safeParse(raw);
      return parsed.success ? { value: parsed.data } : { issue: 'INVALID_NAME' };
    }
    case 'phone': {
      const phone = normalizePhone(raw);
      return phone ? { value: phone } : { issue: 'INVALID_PHONE' };
    }
    case 'email': {
      const parsed = emailSchema.safeParse(raw);
      return parsed.success ? { value: parsed.data } : { issue: 'INVALID_EMAIL' };
    }
    case 'date': {
      const date = normalizeDate(raw);
      return date ? { value: new Date(`${date}T00:00:00.000Z`) } : { issue: 'INVALID_DATE' };
    }
    case 'nationalId': {
      const value = toAsciiDigits(raw).replace(/\s/g, '');
      return value.length >= 10 && value.length <= 20
        ? { value }
        : { issue: 'INVALID_NATIONAL_ID' };
    }
    case 'id': {
      const value = toAsciiDigits(raw).trim();
      return value.length <= 64 ? { value } : { issue: 'TOO_LONG' };
    }
    default:
      return raw.length <= 64 ? { value: raw } : { issue: 'TOO_LONG' };
  }
}

/** Checks one row on its own: required values and formats. */
export function checkRow(
  role: ImportRole,
  row: PersonRow,
): { clean: CleanRow | null; issues: RowIssue[] } {
  const issues: RowIssue[] = [];
  const values: Partial<Record<FieldKey, string | Date>> = {};

  for (const field of fieldsFor(role)) {
    const raw = row[field.key]?.trim() ?? '';
    if (raw === '') {
      if (field.required) issues.push({ field: field.key, code: 'REQUIRED' });
      continue;
    }
    const checked = checkValue(field.type, raw);
    if ('issue' in checked) issues.push({ field: field.key, code: checked.issue });
    else values[field.key] = checked.value;
  }

  if (issues.length > 0) return { clean: null, issues };
  const text = (key: FieldKey) => values[key] as string | undefined;
  const date = (key: FieldKey) => values[key] as Date | undefined;
  return {
    clean: {
      firstName: text('firstName')!,
      lastName: text('lastName')!,
      phone: text('phone')!,
      email: text('email'),
      id: text(idFieldFor(role))!,
      nationalIdOrIqama: text('nationalIdOrIqama'),
      nationality: text('nationality'),
      joinDate: date('joinDate'),
      iqamaExpiry: date('iqamaExpiry'),
    },
    issues,
  };
}

/**
 * Flags phone numbers, emails and ID numbers that appear on more than one row.
 * Every copy is flagged: the admin decides which one is right.
 */
export function findDuplicates(role: ImportRole, rows: (CleanRow | null)[]): RowIssue[][] {
  const issues: RowIssue[][] = rows.map(() => []);
  const keys: Array<[FieldKey, (row: CleanRow) => string | undefined]> = [
    ['phone', (row) => row.phone],
    ['email', (row) => row.email],
    [idFieldFor(role), (row) => row.id],
  ];
  for (const [field, read] of keys) {
    const seen = new Map<string, number[]>();
    rows.forEach((row, index) => {
      const value = row && read(row);
      if (value) seen.set(value, [...(seen.get(value) ?? []), index]);
    });
    for (const indexes of seen.values()) {
      if (indexes.length < 2) continue;
      for (const index of indexes) issues[index].push({ field, code: 'DUPLICATE_IN_LIST' });
    }
  }
  return issues;
}
