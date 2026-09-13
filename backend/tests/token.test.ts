import { describe, it, expect } from 'vitest';
import jwt from 'jsonwebtoken';
import {
  signAccessToken,
  verifyAccessToken,
  generateRefreshToken,
  hashRefreshToken,
} from '../src/utils/token';
import { parseDurationMs } from '../src/utils/duration';

const SECRET = 'test-access-secret-0123456789abcdefghij';

describe('access token', () => {
  it('signs and verifies a token with the correct secret', () => {
    const token = signAccessToken({ sub: 'user-1', type: 'access' }, SECRET, '15m');
    const payload = verifyAccessToken(token, SECRET);
    expect(payload.sub).toBe('user-1');
    expect(payload.type).toBe('access');
  });

  it('rejects a token signed with a different secret', () => {
    const token = signAccessToken(
      { sub: 'user-1', type: 'access' },
      'different-secret-1234567890',
      '15m',
    );
    expect(() => verifyAccessToken(token, SECRET)).toThrow();
  });

  it('rejects an expired token', () => {
    const token = signAccessToken({ sub: 'user-1', type: 'access' }, SECRET, '1s');
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        expect(() => verifyAccessToken(token, SECRET)).toThrow();
        resolve();
      }, 1200);
    });
  });

  it('rejects a token with a non-access type claim', () => {
    const token = jwt.sign({ sub: 'user-1', type: 'refresh' }, SECRET, { expiresIn: '15m' });
    expect(() => verifyAccessToken(token, SECRET)).toThrow();
  });

  it('rejects a token missing the sub claim', () => {
    const token = jwt.sign({ type: 'access' }, SECRET, { expiresIn: '15m' });
    expect(() => verifyAccessToken(token, SECRET)).toThrow();
  });
});

describe('refresh token', () => {
  it('generates a unique, non-empty token and a stable hash', () => {
    const a = generateRefreshToken();
    const b = generateRefreshToken();
    expect(a).not.toBe(b);
    expect(a.length).toBeGreaterThanOrEqual(32);
    expect(hashRefreshToken(a)).toBe(hashRefreshToken(a));
    expect(hashRefreshToken(a)).not.toBe(hashRefreshToken(b));
    expect(hashRefreshToken(a)).toMatch(/^[0-9a-f]{64}$/);
  });
});

describe('parseDurationMs', () => {
  it('parses common units', () => {
    expect(parseDurationMs('15m')).toBe(15 * 60_000);
    expect(parseDurationMs('30d')).toBe(30 * 86_400_000);
    expect(parseDurationMs('1h')).toBe(3_600_000);
    expect(parseDurationMs('90s')).toBe(90_000);
  });

  it('rejects invalid durations', () => {
    expect(() => parseDurationMs('15x')).toThrow();
    expect(() => parseDurationMs('')).toThrow();
  });
});
