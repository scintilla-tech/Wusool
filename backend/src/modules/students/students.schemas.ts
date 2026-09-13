import { z } from 'zod';
import {
  emailSchema,
  latitudeSchema,
  longitudeSchema,
  nameSchema,
  saudiPhoneSchema,
} from '../../validation/common';

export const studentCreateSchema = z
  .object({
    firstName: nameSchema,
    lastName: nameSchema,
    phone: saudiPhoneSchema,
    email: emailSchema.optional(),
    password: z.string().min(8, 'Password must be at least 8 characters').max(200),
    studentId: z.string().trim().min(1).max(64),
    homeLatitude: latitudeSchema.optional(),
    homeLongitude: longitudeSchema.optional(),
  })
  .strict();

export const studentUpdateSchema = studentCreateSchema
  .omit({ password: true, studentId: true })
  .partial()
  .strict();

export const studentListQuerySchema = z
  .object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
  })
  .strict();

export type StudentCreateInput = z.infer<typeof studentCreateSchema>;
export type StudentUpdateInput = z.infer<typeof studentUpdateSchema>;
