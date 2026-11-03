import { vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { createApp } from '../src/app';
import { createLogger } from '../src/config/logger';
import type { EnvConfig } from '../src/config/env';

export const testEnv: EnvConfig = {
  NODE_ENV: 'test',
  PORT: 3000,
  DATABASE_URL: 'postgresql://test:test@localhost:5432/wasl_test?schema=public',
  JWT_ACCESS_SECRET: 'test-access-secret-0123456789abcdefghij',
  JWT_REFRESH_SECRET: 'test-refresh-secret-0123456789abcdefghij',
  JWT_ACCESS_TTL: '15m',
  JWT_REFRESH_TTL: '30d',
  CORS_ALLOWED_ORIGINS: 'http://localhost:3000',
  TRUST_PROXY: 0,
  LOGIN_RATE_LIMIT: 10,
  ATTENDANCE_CUTOFF: '07:00',
  LOG_LEVEL: 'silent',
  ALLOW_DEMO_DEPLOYMENT: false,
  PUBLIC_STUDENT_REGISTRATION: true,
};

export function mockPrisma(): PrismaClient {
  return {
    $queryRaw: vi.fn().mockResolvedValue([{ '?column?': 1 }]),
    $disconnect: vi.fn().mockResolvedValue(undefined),
  } as unknown as PrismaClient;
}

export function createTestApp(prisma: PrismaClient = mockPrisma()) {
  const logger = createLogger(testEnv);
  return createApp({ config: testEnv, logger, prisma });
}
