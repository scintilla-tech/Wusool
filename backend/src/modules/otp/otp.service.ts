import { randomInt } from 'node:crypto';
import type { OtpProvider } from '../../providers/otp';

interface StoredOtp {
  code: string;
  expiresAt: number;
}

const OTP_TTL_MS = 5 * 60 * 1000;
const MAX_VERIFY_ATTEMPTS = 5;
const ATTEMPT_WINDOW_MS = 15 * 60 * 1000;

/**
 * Generates and verifies one-time codes. The in-memory store is sufficient for
 * the single-instance MVP (Redis would back this for multi-instance).
 */
export class OtpService {
  private readonly store = new Map<string, StoredOtp>();
  private readonly attempts = new Map<string, { count: number; windowStart: number }>();

  constructor(
    private readonly provider: OtpProvider,
    private readonly ttlMs: number = OTP_TTL_MS,
  ) {}

  async generate(identifier: string): Promise<string> {
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    this.store.set(identifier, { code, expiresAt: Date.now() + this.ttlMs });
    this.attempts.delete(identifier);
    await this.provider.send(identifier, code);
    return code;
  }

  verify(identifier: string, code: string): boolean {
    const stored = this.store.get(identifier);
    if (!stored || stored.expiresAt < Date.now()) {
      this.store.delete(identifier);
      return false;
    }

    const now = Date.now();
    const attempt = this.attempts.get(identifier) ?? { count: 0, windowStart: now };
    if (now - attempt.windowStart > ATTEMPT_WINDOW_MS) {
      attempt.count = 0;
      attempt.windowStart = now;
    }
    attempt.count += 1;
    this.attempts.set(identifier, attempt);
    if (attempt.count > MAX_VERIFY_ATTEMPTS) {
      this.store.delete(identifier);
      this.attempts.delete(identifier);
      return false;
    }

    if (stored.code !== code) {
      return false;
    }
    this.store.delete(identifier);
    this.attempts.delete(identifier);
    return true;
  }
}
