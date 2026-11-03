import { z } from 'zod';

export const uuidSchema = z.string().trim().uuid('Invalid UUID');

// WASL entity IDs are Prisma CUIDs (v1: 'c' + 24 lowercase alphanumeric chars).
export const idSchema = z
  .string()
  .trim()
  .regex(/^c[a-z0-9]{24}$/, 'Invalid ID');

export const emailSchema = z
  .string()
  .trim()
  .toLowerCase()
  .email('Invalid email address')
  .max(254, 'Email address too long');

const SAUDI_MOBILE_REGEX = /^\+9665\d{8}$/;

export function normalizeSaudiPhone(input: string): string {
  let phone = input.trim().replace(/[\s()-]/g, '');
  if (phone.startsWith('00')) {
    phone = phone.slice(2);
  }
  if (phone.startsWith('0')) {
    phone = `966${phone.slice(1)}`;
  } else if (phone.startsWith('+')) {
    phone = phone.slice(1);
  }
  return phone.startsWith('966') ? `+${phone}` : phone;
}

export const saudiPhoneSchema = z
  .string()
  .trim()
  .transform(normalizeSaudiPhone)
  .refine((value) => SAUDI_MOBILE_REGEX.test(value), 'Invalid Saudi mobile number');

export const nameSchema = z
  .string()
  .trim()
  .min(1, 'Name is required')
  .max(100, 'Name too long')
  .regex(/^[\p{L}\p{M}\s.'’-]+$/u, 'Name contains invalid characters');

const numberOrNumericString = z.union([
  z.number(),
  z
    .string()
    .trim()
    .min(1, 'Value is required')
    .regex(/^-?\d+(\.\d+)?$/, 'Must be a number')
    .transform(Number),
]);

export const latitudeSchema = numberOrNumericString.refine(
  (value) => value >= -90 && value <= 90,
  'Latitude must be between -90 and 90',
);

export const longitudeSchema = numberOrNumericString.refine(
  (value) => value >= -180 && value <= 180,
  'Longitude must be between -180 and 180',
);

export const isoDateSchema = z
  .string()
  .trim()
  .min(1, 'Date is required')
  .refine((value) => !Number.isNaN(Date.parse(value)), 'Invalid date')
  .transform((value) => new Date(value));

export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;

export const paginationSchema = z
  .object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE),
  })
  .strict();
