import { describe, it, expect } from 'vitest';
import { loadEnvConfig, parseCorsOrigins, type EnvConfig } from '../src/config/env';

const validEnv: Record<string, string | undefined> = {
  NODE_ENV: 'test',
  PORT: '3000',
  DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/wasl?schema=public',
  JWT_ACCESS_SECRET: 'test-access-secret-0123456789abcdefghij',
  JWT_REFRESH_SECRET: 'test-refresh-secret-0123456789abcdefghij',
  CORS_ALLOWED_ORIGINS: 'http://localhost:3000',
  LOG_LEVEL: 'silent',
};

describe('environment validation', () => {
  it('accepts valid environment', () => {
    const config: EnvConfig = loadEnvConfig(validEnv);
    expect(config.NODE_ENV).toBe('test');
    expect(config.PORT).toBe(3000);
  });

  it('rejects missing DATABASE_URL', () => {
    const { DATABASE_URL: _omitted, ...rest } = validEnv;
    expect(() => loadEnvConfig(rest)).toThrow(/DATABASE_URL/);
  });

  it('rejects invalid NODE_ENV', () => {
    expect(() => loadEnvConfig({ ...validEnv, NODE_ENV: 'invalid' })).toThrow(/NODE_ENV/);
  });

  it('rejects non-PostgreSQL DATABASE_URL', () => {
    expect(() => loadEnvConfig({ ...validEnv, DATABASE_URL: 'mysql://localhost:3306/db' })).toThrow(
      /PostgreSQL/,
    );
  });

  it('rejects short JWT secrets', () => {
    expect(() => loadEnvConfig({ ...validEnv, JWT_ACCESS_SECRET: 'short' })).toThrow(
      /JWT_ACCESS_SECRET/,
    );
    expect(() => loadEnvConfig({ ...validEnv, JWT_ACCESS_SECRET: 'a'.repeat(31) })).toThrow(
      /at least 32/,
    );
  });

  it('rejects placeholder JWT secrets in production', () => {
    expect(() =>
      loadEnvConfig({
        ...validEnv,
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'change-me-access-secret-please-replace',
        JWT_REFRESH_SECRET: 'change-me-refresh-secret-please-replace',
      }),
    ).toThrow(/placeholder/i);
  });

  it('rejects identical access/refresh secrets in production', () => {
    expect(() =>
      loadEnvConfig({
        ...validEnv,
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'identical-secret-0123456789abcdefghij',
        JWT_REFRESH_SECRET: 'identical-secret-0123456789abcdefghij',
      }),
    ).toThrow(/differ/i);
  });

  it('ignores unrelated environment variables', () => {
    const config = loadEnvConfig({ ...validEnv, PATH: 'C:\\Windows', TEMP: '/tmp', USERNAME: 'x' });
    expect(config.NODE_ENV).toBe('test');
    expect(config.PORT).toBe(3000);
  });

  it('applies defaults when optional values are omitted', () => {
    const { NODE_ENV: _n, PORT: _p, LOG_LEVEL: _l, ...requiredOnly } = validEnv;
    const config = loadEnvConfig(requiredOnly);
    expect(config.NODE_ENV).toBe('development');
    expect(config.PORT).toBe(3000);
    expect(config.LOG_LEVEL).toBe('info');
  });

  it('parses the CORS origin list', () => {
    expect(parseCorsOrigins('http://a.com, http://b.com')).toEqual([
      'http://a.com',
      'http://b.com',
    ]);
  });
});
