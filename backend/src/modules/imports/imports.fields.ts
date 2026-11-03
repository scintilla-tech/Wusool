/**
 * The columns an admin fills in to add people, per role. The same definitions
 * drive the downloadable templates, file header matching and row validation.
 */

export const IMPORT_ROLES = ['STUDENT', 'DRIVER', 'SUPERVISOR', 'FIELD_SUPERVISOR'] as const;
export type ImportRole = (typeof IMPORT_ROLES)[number];

export const FIELD_KEYS = [
  'firstName',
  'lastName',
  'phone',
  'email',
  'studentId',
  'employeeId',
  'nationalIdOrIqama',
  'nationality',
  'joinDate',
  'iqamaExpiry',
] as const;
export type FieldKey = (typeof FIELD_KEYS)[number];

/** One person as typed by the admin: every value is kept as text until added. */
export type PersonRow = Partial<Record<FieldKey, string>>;

export type FieldType = 'name' | 'phone' | 'email' | 'id' | 'nationalId' | 'text' | 'date';

export interface FieldSpec {
  key: FieldKey;
  /** Column header in the template, and the label shown in the app. */
  label: string;
  type: FieldType;
  required: boolean;
  /** Other headers accepted for this column (compared after normalizing). */
  aliases: string[];
}

const firstName: FieldSpec = {
  key: 'firstName',
  label: 'الاسم الأول',
  type: 'name',
  required: true,
  aliases: ['first name', 'firstname', 'الاسم'],
};
const lastName: FieldSpec = {
  key: 'lastName',
  label: 'اسم العائلة',
  type: 'name',
  required: true,
  aliases: ['last name', 'lastname', 'family name', 'العائلة', 'الاسم الأخير'],
};
const phone: FieldSpec = {
  key: 'phone',
  label: 'رقم الجوال',
  type: 'phone',
  required: true,
  aliases: ['phone', 'mobile', 'phone number', 'الجوال', 'رقم الهاتف', 'الهاتف'],
};
const email: FieldSpec = {
  key: 'email',
  label: 'البريد الإلكتروني',
  type: 'email',
  required: false,
  aliases: ['email', 'e-mail', 'البريد', 'الايميل'],
};

const studentFields: FieldSpec[] = [
  firstName,
  lastName,
  phone,
  {
    key: 'studentId',
    label: 'الرقم الجامعي',
    type: 'id',
    required: true,
    aliases: ['student id', 'studentid', 'university id', 'الرقم الاكاديمي'],
  },
  email,
];

const employeeFields: FieldSpec[] = [
  firstName,
  lastName,
  phone,
  {
    key: 'employeeId',
    label: 'الرقم الوظيفي',
    type: 'id',
    required: true,
    aliases: ['employee id', 'employeeid', 'staff id', 'رقم الموظف'],
  },
  email,
  {
    key: 'nationalIdOrIqama',
    label: 'رقم الهوية أو الإقامة',
    type: 'nationalId',
    required: false,
    aliases: ['national id', 'iqama', 'رقم الهوية', 'رقم الإقامة', 'الهوية'],
  },
  {
    key: 'nationality',
    label: 'الجنسية',
    type: 'text',
    required: false,
    aliases: ['nationality'],
  },
  {
    key: 'joinDate',
    label: 'تاريخ الانضمام',
    type: 'date',
    required: false,
    aliases: ['join date', 'joindate', 'start date', 'تاريخ التعيين'],
  },
  {
    key: 'iqamaExpiry',
    label: 'تاريخ انتهاء الإقامة',
    type: 'date',
    required: false,
    aliases: ['iqama expiry', 'iqamaexpiry', 'انتهاء الإقامة'],
  },
];

export function fieldsFor(role: ImportRole): FieldSpec[] {
  return role === 'STUDENT' ? studentFields : employeeFields;
}

/** The field holding the person's university or employee number. */
export function idFieldFor(role: ImportRole): 'studentId' | 'employeeId' {
  return role === 'STUDENT' ? 'studentId' : 'employeeId';
}

/** URL names of the downloadable templates. */
export const TEMPLATE_SLUGS: Record<string, ImportRole> = {
  students: 'STUDENT',
  drivers: 'DRIVER',
  supervisors: 'SUPERVISOR',
  'field-supervisors': 'FIELD_SUPERVISOR',
};

/**
 * A header row only. UTF-8 with a byte order mark so Excel shows the Arabic
 * headers correctly when it opens the file.
 */
export function templateCsv(role: ImportRole): string {
  return `﻿${fieldsFor(role)
    .map((field) => field.label)
    .join(',')}\r\n`;
}

/** Keeps only the fields that belong to the role, trimmed, dropping empty ones. */
export function pickRoleFields(role: ImportRole, row: PersonRow): PersonRow {
  const picked: PersonRow = {};
  for (const field of fieldsFor(role)) {
    const value = row[field.key]?.trim();
    if (value) picked[field.key] = value;
  }
  return picked;
}
