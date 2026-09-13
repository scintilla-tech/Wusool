import { randomInt } from 'node:crypto';
import type { OtpProvider } from '../../providers/otp';

interface StoredOtp {
  code: string;
  expiresAt: number;
}

const OTP_TTL_MS = 5 * 60 * 1000;

/**
 * Generates and verifies one-time codes. The in-memory store is sufficient for
 * the single-instance MVP (Redis would back this for multi-instance).
 */
export class OtpService {
  private readonly store = new Map<string, StoredOtp>();

  constructor(
    private readonly provider: OtpProvider,
    private readonly ttlMs: number = OTP_TTL_MS,
  ) {}

  async generate(identifier: string): Promise<string> {
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    this.store.set(identifier, { code, expiresAt: Date.now() + this.ttlMs });
    await this.provider.send(identifier, code);
    return code;
  }

  verify(identifier: string, code: string): boolean {
    const stored = this.store.get(identifier);
    if (!stored || stored.expiresAt < Date.now()) {
      this.store.delete(identifier);
      return false;
    }
    if (stored.code !== code) {
      return false;
    }
    this.store.delete(identifier);
    return true;
  }
}
