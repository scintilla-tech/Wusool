import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';
import { Prisma, type PrismaClient } from '@prisma/client';
import { createTestApp } from './helpers';
import { readPeopleFile, MAX_IMPORT_ROWS } from '../src/modules/imports/imports.file';
import { ImportsService } from '../src/modules/imports/imports.service';
import {
  checkRow,
  findDuplicates,
  normalizeDate,
  normalizePhone,
} from '../src/modules/imports/imports.validation';

const fixture = (name: string) => readFileSync(resolve(__dirname, 'fixtures', name));
const csv = (text: string) => Buffer.from(text, 'utf8');

const sara = {
  firstName: 'سارة',
  lastName: 'العتيبي',
  phone: '0500000201',
  studentId: '441000001',
};

describe('row checks', () => {
  it('accepts phone numbers the way people and spreadsheets write them', () => {
    expect(normalizePhone('0500000201')).toBe('+966500000201');
    expect(normalizePhone('500000201')).toBe('+966500000201');
    expect(normalizePhone('٠٥٠٠٠٠٠٢٠١')).toBe('+966500000201');
    expect(normalizePhone('+966 50 000 0201')).toBe('+966500000201');
    expect(normalizePhone('12345')).toBeNull();
  });

  it('reads Gregorian dates year first or day first, and rejects the rest', () => {
    expect(normalizeDate('2026-11-02')).toBe('2026-11-02');
    expect(normalizeDate('2/11/2026')).toBe('2026-11-02');
    expect(normalizeDate('٠٢/١١/٢٠٢٦')).toBe('2026-11-02');
    expect(normalizeDate('31/02/2026')).toBeNull();
    expect(normalizeDate('1448-05-01')).toBeNull();
    expect(normalizeDate('next week')).toBeNull();
  });

  it('reports each missing or malformed value against its field', () => {
    const { clean, issues } = checkRow('STUDENT', {
      firstName: 'سارة',
      phone: '123',
      studentId: '441000001',
      email: 'not-an-email',
    });

    expect(clean).toBeNull();
    expect(issues).toEqual([
      { field: 'lastName', code: 'REQUIRED' },
      { field: 'phone', code: 'INVALID_PHONE' },
      { field: 'email', code: 'INVALID_EMAIL' },
    ]);
  });

  it('accepts names written with Arabic diacritics', () => {
    expect(
      checkRow('STUDENT', { ...sara, firstName: 'مُنيرة', lastName: 'الشّهري' }).issues,
    ).toEqual([]);
  });

  it('turns a valid employee row into account values', () => {
    const { clean, issues } = checkRow('DRIVER', {
      firstName: 'Khalid',
      lastName: 'Saleh',
      phone: '0500000301',
      employeeId: 'DRV-301',
      joinDate: '01/11/2025',
    });

    expect(issues).toEqual([]);
    expect(clean).toMatchObject({ phone: '+966500000301', id: 'DRV-301' });
    expect(clean?.joinDate?.toISOString()).toBe('2025-11-01T00:00:00.000Z');
  });

  it('flags every copy of a repeated phone, email or ID', () => {
    const rows = [
      sara,
      { ...sara, phone: '0500000202' },
      { ...sara, studentId: '441000003', phone: '500000202' },
    ].map((row) => checkRow('STUDENT', row).clean);

    expect(findDuplicates('STUDENT', rows)).toEqual([
      [{ field: 'studentId', code: 'DUPLICATE_IN_LIST' }],
      [
        { field: 'phone', code: 'DUPLICATE_IN_LIST' },
        { field: 'studentId', code: 'DUPLICATE_IN_LIST' },
      ],
      [{ field: 'phone', code: 'DUPLICATE_IN_LIST' }],
    ]);
  });
});

describe('reading files', () => {
  it('reads an Excel sheet, skipping blank rows and keeping numbers as text', async () => {
    const { rows, missingColumns } = await readPeopleFile(
      'STUDENT',
      fixture('students.xlsx'),
      'الدفعة.xlsx',
    );

    expect(missingColumns).toEqual([]);
    expect(rows).toEqual([
      { ...sara, phone: '500000201' },
      {
        firstName: 'نورة',
        lastName: 'القحطاني',
        phone: '0500000202',
        studentId: '441000002',
        email: 'noura@example.com',
      },
    ]);
  });

  it('matches English headers and reads date cells', async () => {
    const { rows } = await readPeopleFile('DRIVER', fixture('drivers.xlsx'), 'drivers.xlsx');

    expect(rows).toEqual([
      {
        firstName: 'Khalid',
        lastName: 'Saleh',
        phone: '0500000301',
        employeeId: 'DRV-301',
        joinDate: '2025-11-01',
      },
    ]);
  });

  it('reads a UTF-8 CSV with a byte order mark and semicolons', async () => {
    const file = csv(
      '﻿الاسم الأول;اسم العائلة;رقم الجوال;الرقم الجامعي\nسارة;العتيبي;0500000201;441000001\n',
    );

    const { rows } = await readPeopleFile('STUDENT', file, 'students.csv');
    expect(rows).toEqual([sara]);
  });

  it('reads a CSV that Excel saved in the Arabic Windows code page', async () => {
    // English headers, then "سارة" in Windows-1256 bytes.
    const header = Buffer.from('first name,last name,phone,student id\n', 'ascii');
    const sarah = Buffer.from([0xd3, 0xc7, 0xd1, 0xc9]); // سارة
    const file = Buffer.concat([
      header,
      sarah,
      Buffer.from(',Ali,0500000201,441000001\n', 'ascii'),
    ]);

    const { rows } = await readPeopleFile('STUDENT', file, 'students.csv');
    expect(rows[0].firstName).toBe('سارة');
  });

  it('names the required columns a file is missing', async () => {
    const file = csv('الاسم الأول,رقم الجوال\nسارة,0500000201\n');

    const { rows, missingColumns } = await readPeopleFile('STUDENT', file, 'students.csv');
    expect(rows).toEqual([]);
    expect(missingColumns).toEqual(['lastName', 'studentId']);
  });

  it('refuses old .xls workbooks and other files', async () => {
    const xls = Buffer.from([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]);

    await expect(readPeopleFile('STUDENT', xls, 'old.xls')).rejects.toMatchObject({
      code: 'UNSUPPORTED_FILE',
    });
    await expect(readPeopleFile('STUDENT', csv('%PDF-1.7'), 'list.pdf')).rejects.toMatchObject({
      code: 'UNSUPPORTED_FILE',
    });
  });

  it('refuses files with more people than one import allows', async () => {
    const lines = Array.from({ length: MAX_IMPORT_ROWS + 1 }, (_, i) => `a,b,05000${i},${i}`);
    const file = csv(`first name,last name,phone,student id\n${lines.join('\n')}`);

    await expect(readPeopleFile('STUDENT', file, 'big.csv')).rejects.toMatchObject({
      code: 'TOO_MANY_ROWS',
    });
  });
});

describe('templates', () => {
  it('serves a header-only CSV that Excel opens with Arabic intact', async () => {
    const response = await request(createTestApp()).get('/api/v1/imports/templates/students');

    expect(response.status).toBe(200);
    expect(response.headers['content-type']).toContain('text/csv');
    expect(response.headers['content-disposition']).toContain('wusool-students.csv');
    expect(response.text).toBe(
      '﻿الاسم الأول,اسم العائلة,رقم الجوال,الرقم الجامعي,البريد الإلكتروني\r\n',
    );
  });
});

function importsPrisma(overrides: Record<string, unknown> = {}) {
  const tx = {
    user: {
      create: vi.fn().mockResolvedValue({ id: 'new-user' }),
      findUniqueOrThrow: vi.fn().mockResolvedValue({ id: 'new-user', studentProfile: null }),
    },
    studentProfile: { create: vi.fn().mockResolvedValue({}) },
  };
  const prisma = {
    user: { findMany: vi.fn().mockResolvedValue([]) },
    studentProfile: { findMany: vi.fn().mockResolvedValue([]) },
    auditLog: { create: vi.fn().mockResolvedValue({}) },
    importDraft: {
      findFirst: vi.fn().mockResolvedValue({
        id: 'draft1',
        role: 'STUDENT',
        name: 'الدفعة',
        rows: [],
        updatedAt: new Date(),
        createdBy: { firstName: 'Admin', lastName: 'KKU' },
      }),
      update: vi.fn(async ({ data }) => ({
        id: 'draft1',
        role: 'STUDENT',
        name: 'الدفعة',
        rows: data.rows,
        updatedAt: new Date(),
        createdBy: { firstName: 'Admin', lastName: 'KKU' },
      })),
      deleteMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    $transaction: vi.fn(async (fn: (client: typeof tx) => unknown) => fn(tx)),
    ...overrides,
  };
  return { prisma: prisma as unknown as PrismaClient, raw: prisma, tx };
}

describe('adding people', () => {
  it('flags values that existing accounts already use', async () => {
    const { prisma } = importsPrisma({
      user: { findMany: vi.fn().mockResolvedValue([{ phone: '+966500000201' }]) },
      studentProfile: { findMany: vi.fn().mockResolvedValue([{ studentId: '441000001' }]) },
    });

    const issues = await new ImportsService(prisma).check('tenant1', 'STUDENT', [sara]);
    expect(issues).toEqual([
      [
        { field: 'phone', code: 'PHONE_TAKEN' },
        { field: 'studentId', code: 'ID_TAKEN' },
      ],
    ]);
  });

  it('creates accounts without a password and keeps rows with problems in the draft', async () => {
    const { prisma, raw, tx } = importsPrisma();
    const broken = { firstName: 'نورة', phone: '0500000202', studentId: '441000002' };

    const result = await new ImportsService(prisma).submit(
      'tenant1',
      'admin1',
      'STUDENT',
      [sara, broken],
      'draft1',
    );

    expect(result.created).toBe(1);
    expect(tx.user.create.mock.calls[0][0].data).toMatchObject({ phone: '+966500000201' });
    expect(tx.user.create.mock.calls[0][0].data).not.toHaveProperty('passwordHash');
    expect(result.rows).toEqual([broken]);
    expect(result.issues).toEqual([[{ field: 'lastName', code: 'REQUIRED' }]]);
    expect(raw.importDraft.update.mock.calls[0][0].data.rows).toEqual([broken]);
    expect(result.draft).toMatchObject({ id: 'draft1', rowCount: 1 });
    expect(raw.auditLog.create.mock.calls[0][0].data).toMatchObject({
      action: 'PEOPLE_ADDED',
      metadata: { role: 'STUDENT', count: 1, draftId: 'draft1' },
    });
  });

  it('deletes the draft once every row is added', async () => {
    const { prisma, raw } = importsPrisma();

    const result = await new ImportsService(prisma).submit(
      'tenant1',
      'admin1',
      'STUDENT',
      [sara],
      'draft1',
    );

    expect(result).toMatchObject({ created: 1, rows: [], draft: null });
    expect(raw.importDraft.deleteMany).toHaveBeenCalledWith({
      where: { id: 'draft1', tenantId: 'tenant1' },
    });
  });

  it('keeps a row another admin added in the meantime', async () => {
    const { prisma } = importsPrisma({
      $transaction: vi.fn().mockRejectedValue(
        new Prisma.PrismaClientKnownRequestError('unique', {
          code: 'P2002',
          clientVersion: 'test',
          meta: { target: ['tenantId', 'phone'] },
        }),
      ),
    });

    const result = await new ImportsService(prisma).submit('tenant1', 'admin1', 'STUDENT', [sara]);
    expect(result.created).toBe(0);
    expect(result.issues).toEqual([[{ field: 'phone', code: 'PHONE_TAKEN' }]]);
  });

  it('refuses rows of another kind than the draft holds', async () => {
    const { prisma } = importsPrisma();

    await expect(
      new ImportsService(prisma).submit('tenant1', 'admin1', 'DRIVER', [sara], 'draft1'),
    ).rejects.toMatchObject({ statusCode: 409, code: 'DRAFT_ROLE_MISMATCH' });
  });
});
