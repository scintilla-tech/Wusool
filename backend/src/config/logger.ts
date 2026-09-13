import pino from 'pino';
import type { EnvConfig } from './env';

const SENSITIVE_PATTERNS: Array<[RegExp, string]> = [
  [/(postgres(?:ql)?:\/\/)[^@\s]+@/gi, '$1[REDACTED]@'],
  [/(password\s*[:=]\s*)[^\s,;]+/gi, '$1[REDACTED]'],
  [/(secret\s*[:=]\s*)[^\s,;]+/gi, '$1[REDACTED]'],
  [/(token\s*[:=]\s*)[^\s,;]+/gi, '$1[REDACTED]'],
  [/(nationalIdOrIqama\s*[:=]\s*)[^\s,;]+/gi, '$1[REDACTED]'],
  [/(documentKey\s*[:=]\s*)[^\s,;]+/gi, '$1[REDACTED]'],
  [/(licenseNumber\s*[:=]\s*)[^\s,;]+/gi, '$1[REDACTED]'],
  [/\+9665\d{8}/g, '[REDACTED]'],
];

export function scrub(value: string): string {
  let result = value;
  for (const [pattern, replacement] of SENSITIVE_PATTERNS) {
    result = result.replace(pattern, replacement);
  }
  return result;
}

function serializeError(err: unknown): unknown {
  if (err instanceof Error) {
    return {
      name: err.name,
      message: scrub(err.message),
      stack: scrub(err.stack ?? ''),
    };
  }
  return err;
}

export function createLogger(env: EnvConfig): pino.Logger {
  const level = env.NODE_ENV === 'test' ? 'silent' : env.LOG_LEVEL;

  return pino({
    level,
    base: { app: 'wasl', env: env.NODE_ENV },
    serializers: {
      err: serializeError,
    },
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        'req.headers["x-api-key"]',
        'req.body.password',
        'req.body.passwordHash',
        'req.body.nationalIdOrIqama',
        'req.body.token',
        'req.body.refreshToken',
        'req.body.homeLatitude',
        'req.body.homeLongitude',
        'req.body.documentKey',
        'req.body.licenseNumber',
        'req.body.iqamaExpiry',
        'req.body.*.nationalIdOrIqama',
        'req.body.*.documentKey',
        'req.body.*.homeLatitude',
        'req.body.*.homeLongitude',
        'req.body.*.licenseNumber',
        'req.body.*.iqamaExpiry',
        'res.headers["set-cookie"]',
      ],
      censor: '[REDACTED]',
    },
  });
}
