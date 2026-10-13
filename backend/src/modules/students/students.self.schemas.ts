import { z } from 'zod';
import {
  emailSchema,
  idSchema,
  latitudeSchema,
  longitudeSchema,
  nameSchema,
  saudiPhoneSchema,
} from '../../validation/common';

export const registerSchema = z
  .object({
    tenantCode: z.string().trim().min(1).max(64),
    firstName: nameSchema,
    lastName: nameSchema,
    email: emailSchema.optional(),
    phone: saudiPhoneSchema,
    password: z.string().min(8, 'Password must be at least 8 characters').max(200),
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

export const verifySchema = z
  .object({
    userId: idSchema,
    code: z
      .string()
      .trim()
      .regex(/^\d{6}$/, 'Code must be 6 digits'),
  })
  .strict();

export const profileUpdateSchema = z
  .object({
    phone: saudiPhoneSchema.optional(),
    email: emailSchema.optional(),
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

export type RegisterInput = z.infer<typeof registerSchema>;
export type VerifyInput = z.infer<typeof verifySchema>;
export type ProfileUpdateInput = z.infer<typeof profileUpdateSchema>;
