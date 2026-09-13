import { z } from 'zod';
import { saudiPhoneSchema } from '../../validation/common';

export const loginSchema = z
  .object({
    tenantCode: z.string().trim().min(1, 'Tenant code is required').max(64),
    phone: saudiPhoneSchema,
    password: z.string().min(1, 'Password is required').max(200),
  })
  .strict();

export const refreshSchema = z
  .object({
    refreshToken: z.string().trim().min(16, 'Invalid refresh token').max(512),
  })
  .strict();

export type LoginInput = z.infer<typeof loginSchema>;
export type RefreshInput = z.infer<typeof refreshSchema>;
