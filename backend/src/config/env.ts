import { z } from 'zod';

const booleanString = z
  .enum(['true', 'false'])
  .default('false')
  .transform((value) => value === 'true');

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
    JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET must be at least 32 characters'),
    // Reserved for a future JWT-based refresh token design. Refresh tokens are
    // currently opaque random values (SHA-256 hashed), so this secret is unused
    // but kept as a required placeholder per the approved environment contract.
    JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET must be at least 32 characters'),
    JWT_ACCESS_TTL: z
      .string()
      .regex(/^\d+(ms|s|m|h|d)$/, 'JWT_ACCESS_TTL must be a duration like "15m"')
      .default('15m'),
    JWT_REFRESH_TTL: z
      .string()
      .regex(/^\d+(ms|s|m|h|d)$/, 'JWT_REFRESH_TTL must be a duration like "30d"')
      .default('30d'),
    CORS_ALLOWED_ORIGINS: z.string().min(1, 'CORS_ALLOWED_ORIGINS is required'),
    TRUST_PROXY: z.coerce.number().int().min(0).max(10).default(0),
    LOGIN_RATE_LIMIT: z.coerce.number().int().min(1).default(10),
    ATTENDANCE_CUTOFF: z
      .string()
      .regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'ATTENDANCE_CUTOFF must be a HH:mm time')
      .default('07:00'),
    LOG_LEVEL: z
      .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
      .default('info'),
    // Explicit escape hatch for the hackathon staging environment. This never
    // permits a production boot with mock OTP/push/local-storage providers.
    ALLOW_DEMO_DEPLOYMENT: booleanString,
    // Public self-registration is disabled in the cloud demo because its OTP
    // provider is intentionally a no-op. Seeded demo accounts remain usable.
    PUBLIC_STUDENT_REGISTRATION: z
      .enum(['true', 'false'])
      .default('true')
      .transform((value) => value === 'true'),
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
      if (value.ALLOW_DEMO_DEPLOYMENT) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['ALLOW_DEMO_DEPLOYMENT'],
          message: 'must be false in production',
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
  'JWT_ACCESS_TTL',
  'JWT_REFRESH_TTL',
  'CORS_ALLOWED_ORIGINS',
  'TRUST_PROXY',
  'LOGIN_RATE_LIMIT',
  'ATTENDANCE_CUTOFF',
  'LOG_LEVEL',
  'ALLOW_DEMO_DEPLOYMENT',
  'PUBLIC_STUDENT_REGISTRATION',
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
