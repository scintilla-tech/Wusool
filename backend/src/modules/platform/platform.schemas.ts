import { z } from 'zod';
import { nameSchema, saudiPhoneSchema } from '../../validation/common';

export const tenantCreateSchema = z
  .object({
    code: z.string().trim().min(1).max(64),
    name: z.string().trim().min(1).max(200),
    admin: z
      .object({
        firstName: nameSchema,
        lastName: nameSchema,
        phone: saudiPhoneSchema,
        password: z.string().min(8).max(200),
      })
      .strict()
      .optional(),
  })
  .strict();

export const tenantUpdateSchema = z
  .object({
    name: z.string().trim().min(1).max(200).optional(),
    isActive: z.boolean().optional(),
  })
  .strict();

export type TenantCreateInput = z.infer<typeof tenantCreateSchema>;
export type TenantUpdateInput = z.infer<typeof tenantUpdateSchema>;
