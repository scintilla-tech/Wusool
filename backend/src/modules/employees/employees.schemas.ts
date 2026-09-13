import { z } from 'zod';
import { emailSchema, isoDateSchema, nameSchema, saudiPhoneSchema } from '../../validation/common';

export const employeeCreateSchema = z
  .object({
    role: z.enum(['DRIVER', 'SUPERVISOR', 'FIELD_SUPERVISOR']),
    firstName: nameSchema,
    lastName: nameSchema,
    phone: saudiPhoneSchema,
    email: emailSchema.optional(),
    password: z.string().min(8, 'Password must be at least 8 characters').max(200),
    employeeId: z.string().trim().min(1).max(64),
    nationalIdOrIqama: z.string().trim().min(10).max(20).optional(),
    nationality: z.string().trim().min(1).max(64).optional(),
    joinDate: isoDateSchema.optional(),
    iqamaExpiry: isoDateSchema.optional(),
    employmentStatus: z.enum(['ACTIVE', 'INACTIVE', 'SUSPENDED']).default('ACTIVE'),
  })
  .strict();

export const employeeUpdateSchema = employeeCreateSchema
  .omit({ role: true, password: true })
  .partial()
  .strict();

export const employeeListQuerySchema = z
  .object({
    role: z.enum(['DRIVER', 'SUPERVISOR', 'FIELD_SUPERVISOR']),
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
  })
  .strict();

export type EmployeeCreateInput = z.infer<typeof employeeCreateSchema>;
export type EmployeeUpdateInput = z.infer<typeof employeeUpdateSchema>;
