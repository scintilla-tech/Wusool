import { describe, it, expect } from 'vitest';
import { hashPassword, verifyPassword } from '../src/utils/password';

describe('password hashing (Argon2id)', () => {
  it('hashes and verifies a correct password', async () => {
    const hashed = await hashPassword('correct-horse-battery-staple');
    expect(hashed).not.toBe('correct-horse-battery-staple');
    expect(hashed).toContain('$argon2id$');
    await expect(verifyPassword(hashed, 'correct-horse-battery-staple')).resolves.toBe(true);
  });

  it('rejects a wrong password', async () => {
    const hashed = await hashPassword('correct-horse-battery-staple');
    await expect(verifyPassword(hashed, 'wrong-password')).resolves.toBe(false);
  });

  it('produces unique hashes for the same password (salted)', async () => {
    const a = await hashPassword('same-password');
    const b = await hashPassword('same-password');
    expect(a).not.toBe(b);
  });

  it('returns false for a malformed hash instead of throwing', async () => {
    await expect(verifyPassword('not-a-valid-hash', 'whatever')).resolves.toBe(false);
  });
});
