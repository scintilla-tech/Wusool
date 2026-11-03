import type { PrismaClient, User } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { hashPassword } from '../../utils/password';
import type { OtpService } from '../otp/otp.service';
import type { AuthService, AuthUserDto, TokenPair } from './auth.service';

function invalidCode(): AppError {
  return new AppError(400, 'INVALID_CODE', 'Invalid or expired verification code');
}

/**
 * First sign-in for accounts an admin added: they have no password yet, so the
 * owner proves the phone with a one-time code and chooses a password.
 *
 * Responses never reveal whether a phone belongs to such an account, matching
 * the login endpoint's protection against account enumeration.
 */
export class ActivationService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly otp: OtpService,
    private readonly auth: AuthService,
    /** Development only: return the code so the flow works without SMS. */
    private readonly exposeCode: boolean,
  ) {}

  async request(tenantCode: string, phone: string): Promise<{ devOtp?: string }> {
    const user = await this.findPendingUser(tenantCode, phone);
    if (!user) return {};
    const code = await this.otp.generate(otpKey(user), user.phone);
    return this.exposeCode ? { devOtp: code } : {};
  }

  async complete(
    tenantCode: string,
    phone: string,
    code: string,
    password: string,
  ): Promise<TokenPair & { user: AuthUserDto }> {
    const user = await this.findPendingUser(tenantCode, phone);
    if (!user || !this.otp.verify(otpKey(user), code)) throw invalidCode();

    const passwordHash = await hashPassword(password);
    const activated = await this.prisma.$transaction(async (tx) => {
      // Guard against two completions racing: only the first sets the password.
      const result = await tx.user.updateMany({
        where: { id: user.id, passwordHash: null },
        data: { passwordHash },
      });
      if (result.count === 1) {
        await tx.auditLog.create({
          data: {
            tenantId: user.tenantId,
            actorUserId: user.id,
            action: 'ACCOUNT_ACTIVATED',
            entityType: 'User',
            entityId: user.id,
          },
        });
      }
      return result.count === 1;
    });
    if (!activated) throw invalidCode();

    return this.auth.startSession({ ...user, passwordHash });
  }

  /** An active account in an active university that has no password yet. */
  private async findPendingUser(tenantCode: string, phone: string): Promise<User | null> {
    const tenant = await this.prisma.tenant.findUnique({ where: { code: tenantCode } });
    if (!tenant || !tenant.isActive) return null;
    const user = await this.prisma.user.findUnique({
      where: { tenantId_phone: { tenantId: tenant.id, phone } },
    });
    if (!user || !user.isActive || user.passwordHash) return null;
    return user;
  }
}

function otpKey(user: User): string {
  return `activation:${user.id}`;
}
