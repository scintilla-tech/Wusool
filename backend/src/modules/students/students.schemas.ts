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
    studentId: z.string().trim().min(1).max(64),
    homeLatitude: latitudeSchema.optional(),
    homeLongitude: longitudeSchema.optional(),
  })
  .strict()
  .superRefine((value, ctx) => {
    if ((value.homeLatitude === undefined) !== (value.homeLongitude === undefined)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['homeLatitude'],
        message: 'Home latitude and longitude must be provided together',
      });
    }
  });

export const studentUpdateSchema = z
  .object({
    firstName: nameSchema.optional(),
    lastName: nameSchema.optional(),
    phone: saudiPhoneSchema.optional(),
    email: emailSchema.optional(),
    homeLatitude: latitudeSchema.optional(),
    homeLongitude: longitudeSchema.optional(),
  })
  .partial()
  .strict()
  .superRefine((value, ctx) => {
    if ((value.homeLatitude === undefined) !== (value.homeLongitude === undefined)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['homeLatitude'],
        message: 'Home latitude and longitude must be provided together',
      });
    }
  });

export const studentListQuerySchema = z
  .object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
  })
  .strict();

export type StudentCreateInput = z.infer<typeof studentCreateSchema>;
export type StudentUpdateInput = z.infer<typeof studentUpdateSchema>;
