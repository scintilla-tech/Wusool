import { z } from 'zod';

export const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'staging', 'production']).default('development'),
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),
    DATABASE_URL: z
      .string()
      .min(1, 'DATABASE_URL is required')
      .refine(
        (v) => v.startsWith('postgresql://') || v.startsWith('postgres://'),
        'DATABASE_URL must be a PostgreSQL connection string',
      ),
    JWT_ACCESS_SECRET: z.string().min(16, 'JWT_ACCESS_SECRET must be at least 16 characters'),
    JWT_REFRESH_SECRET: z.string().min(16, 'JWT_REFRESH_SECRET must be at least 16 characters'),
    CORS_ALLOWED_ORIGINS: z.string().min(1, 'CORS_ALLOWED_ORIGINS is required'),
    LOG_LEVEL: z
      .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
      .default('info'),
  })
  .superRefine((value, ctx) => {
    if (value.NODE_ENV === 'production') {
      const placeholder = /(change-me|example|placeholder|your-?secret|test-?secret)/i;
      if (placeholder.test(value.JWT_ACCESS_SECRET)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['JWT_ACCESS_SECRET'],
          message: 'must not be a placeholder value in production',
        });
      }
      if (placeholder.test(value.JWT_REFRESH_SECRET)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['JWT_REFRESH_SECRET'],
          message: 'must not be a placeholder value in production',
        });
      }
      if (value.JWT_ACCESS_SECRET === value.JWT_REFRESH_SECRET) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['JWT_REFRESH_SECRET'],
          message: 'must differ from JWT_ACCESS_SECRET in production',
        });
      }
    }
  });

export type EnvConfig = z.infer<typeof envSchema>;

const ENV_KEYS = [
  'NODE_ENV',
  'PORT',
  'DATABASE_URL',
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'CORS_ALLOWED_ORIGINS',
  'LOG_LEVEL',
] as const;

/**
 * Validates only the WASL configuration keys. `process.env` contains many
 * unrelated system variables, so strict-parsing the whole object would fail.
 * We explicitly whitelist the known keys before validation.
 */
export function loadEnvConfig(source: Record<string, string | undefined> = process.env): EnvConfig {
  const picked: Record<string, string | undefined> = {};
  for (const key of ENV_KEYS) {
    picked[key] = source[key];
  }

  const parsed = envSchema.safeParse(picked);
  if (!parsed.success) {
    const issues = parsed.error.issues
      .map((issue) => `${issue.path.join('.') || '(root)'}: ${issue.message}`)
      .join('; ');
    throw new Error(`Invalid environment configuration: ${issues}`);
  }
  return parsed.data;
}

export function parseCorsOrigins(corsAllowedOrigins: string): string[] {
  return corsAllowedOrigins
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}
