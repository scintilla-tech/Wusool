import { parse as parseCsv } from 'csv-parse/sync';
import { readSheet } from 'read-excel-file/node';
import { AppError } from '../../utils/appError';
import { fieldsFor, type FieldKey, type ImportRole, type PersonRow } from './imports.fields';

export const MAX_IMPORT_ROWS = 1000;
export const MAX_IMPORT_FILE_BYTES = 2 * 1024 * 1024;

export interface ReadFileResult {
  rows: PersonRow[];
  /** Required columns the file's header row does not have. */
  missingColumns: FieldKey[];
}

type Cell = string | number | boolean | Date | null | undefined;

function unreadable(): AppError {
  return new AppError(422, 'UNREADABLE_FILE', 'The file could not be read');
}

const startsWith = (buffer: Buffer, bytes: number[]) =>
  bytes.every((byte, index) => buffer[index] === byte);

/** Header text compared without case, spacing, punctuation or Arabic letter variants. */
export function normalizeHeader(value: string): string {
  return value
    .toLowerCase()
    .replace(/[ً-ْـ]/g, '') // diacritics and tatweel
    .replace(/[أإآ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/\(.*?\)|\*/g, '')
    .replace(/[\s_\-.:]+/g, '');
}

function cellText(cell: Cell): string {
  if (cell === null || cell === undefined) return '';
  if (cell instanceof Date) {
    return Number.isNaN(cell.getTime()) ? '' : cell.toISOString().slice(0, 10);
  }
  return String(cell).trim();
}

/** Decodes CSV bytes: UTF-8 when valid, otherwise the Arabic Windows code page Excel uses. */
function decodeText(buffer: Buffer): string {
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(buffer);
  } catch {
    return new TextDecoder('windows-1256').decode(buffer);
  }
}

function readCsv(buffer: Buffer): Cell[][] {
  const text = decodeText(buffer).replace(/^﻿/, '');
  const firstLine = text.slice(0, text.search(/\r?\n|$/));
  // Excel uses ";" in locales where "," is the decimal separator.
  const delimiter = [',', ';', '\t'].reduce((best, candidate) =>
    firstLine.split(candidate).length > firstLine.split(best).length ? candidate : best,
  );
  try {
    return parseCsv(text, {
      delimiter,
      relax_column_count: true,
      relax_quotes: true,
      skip_empty_lines: true,
      trim: true,
    }) as string[][];
  } catch {
    throw unreadable();
  }
}

async function readXlsx(buffer: Buffer): Promise<Cell[][]> {
  try {
    return (await readSheet(buffer)) as unknown as Cell[][];
  } catch {
    throw unreadable();
  }
}

/** Reads the people listed in an Excel (.xlsx) or CSV file. */
export async function readPeopleFile(
  role: ImportRole,
  buffer: Buffer,
  fileName: string,
): Promise<ReadFileResult> {
  let table: Cell[][];
  if (startsWith(buffer, [0x50, 0x4b, 0x03, 0x04])) {
    table = await readXlsx(buffer);
  } else if (
    startsWith(buffer, [0xd0, 0xcf, 0x11, 0xe0]) ||
    !/\.(csv|txt)$/i.test(fileName) ||
    buffer.includes(0)
  ) {
    // Old .xls workbooks and anything else that is not text.
    throw new AppError(415, 'UNSUPPORTED_FILE', 'Upload an Excel (.xlsx) or CSV file');
  } else {
    table = readCsv(buffer);
  }

  const lines = table
    .map((line) => line.map(cellText))
    .filter((line) => line.some((value) => value !== ''));
  const [header = [], ...data] = lines;

  const fields = fieldsFor(role);
  const columnOf = new Map<FieldKey, number>();
  header.forEach((title, column) => {
    const normalized = normalizeHeader(title);
    const field = fields.find(
      (candidate) =>
        normalizeHeader(candidate.label) === normalized ||
        candidate.key.toLowerCase() === normalized ||
        candidate.aliases.some((alias) => normalizeHeader(alias) === normalized),
    );
    if (field && !columnOf.has(field.key)) columnOf.set(field.key, column);
  });

  const missingColumns = fields
    .filter((field) => field.required && !columnOf.has(field.key))
    .map((field) => field.key);
  if (missingColumns.length > 0) return { rows: [], missingColumns };

  if (data.length > MAX_IMPORT_ROWS) {
    throw new AppError(
      422,
      'TOO_MANY_ROWS',
      `A file can list at most ${MAX_IMPORT_ROWS} people; split it into smaller files`,
    );
  }

  const rows = data.map((line) => {
    const row: PersonRow = {};
    for (const [key, column] of columnOf) {
      const value = line[column] ?? '';
      if (value !== '') row[key] = value.slice(0, 300);
    }
    return row;
  });
  return { rows, missingColumns: [] };
}
