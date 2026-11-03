import { z } from 'zod';
import { IMPORT_ROLES } from './imports.fields';
import { MAX_IMPORT_ROWS } from './imports.file';

const cell = z.string().max(300).optional();

/** Values are free text here; the row checks report what is wrong with each. */
export const personRowSchema = z
  .object({
    firstName: cell,
    lastName: cell,
    phone: cell,
    email: cell,
    studentId: cell,
    employeeId: cell,
    nationalIdOrIqama: cell,
    nationality: cell,
    joinDate: cell,
    iqamaExpiry: cell,
  })
  .strict();

const roleSchema = z.enum(IMPORT_ROLES);
const rowsSchema = z.array(personRowSchema).max(MAX_IMPORT_ROWS);
const draftNameSchema = z.string().trim().min(1).max(120);

export const checkRowsSchema = z.object({ role: roleSchema, rows: rowsSchema }).strict();

export const submitRowsSchema = z
  .object({
    role: roleSchema,
    rows: rowsSchema.min(1),
    /** The draft the rows came from: emptied rows are removed, the rest saved. */
    draftId: z.string().trim().min(1).max(64).optional(),
  })
  .strict();

export const readFileFieldsSchema = z
  .object({ role: roleSchema, name: draftNameSchema.optional() })
  .strict();

export const draftListQuerySchema = z.object({ role: roleSchema }).strict();

export const draftCreateSchema = z
  .object({ role: roleSchema, name: draftNameSchema, rows: rowsSchema.min(1) })
  .strict();

export const draftUpdateSchema = z
  .object({ name: draftNameSchema.optional(), rows: rowsSchema.min(1) })
  .strict();

export type CheckRowsInput = z.infer<typeof checkRowsSchema>;
export type SubmitRowsInput = z.infer<typeof submitRowsSchema>;
export type DraftListQuery = z.infer<typeof draftListQuerySchema>;
