import type { PrismaClient, Role, User } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { verifyPassword } from '../../utils/password';
import { signAccessToken, generateRefreshToken, hashRefreshToken } from '../../utils/token';
import { parseDurationMs } from '../../utils/duration';

export interface AuthConfig {
  accessSecret: string;
  accessTtl: string;
  refreshTtl: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface AuthUserDto {
  id: string;
  tenantId: string | null;
  role: Role;
  firstName: string;
  lastName: string;
  email: string | null;
  phone: string;
  isActive: boolean;
}

/**
 * Precomputed Argon2id hash used to equalize login timing on failure paths,
 * preventing user/tenant enumeration via response latency.
 */
const DUMMY_PASSWORD_HASH =
  '$argon2id$v=19$m=19456,t=2,p=1$CN2RRmqGCSjWf+9R+9AgLg$hnWRyLnXjuBJm5ANI1ULS1XiTRHQQ1xCT4PvWehdhRo';

function toUserDto(user: User): AuthUserDto {
  return {
    id: user.id,
    tenantId: user.tenantId,
    role: user.role,
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    phone: user.phone,
    isActive: user.isActive,
  };
}

function invalidCredentials(): AppError {
  return new AppError(401, 'INVALID_CREDENTIALS', 'Invalid credentials');
}

export class AuthService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly config: AuthConfig,
  ) {}

  async login(
    tenantCode: string | undefined,
    phone: string,
    password: string,
  ): Promise<TokenPair & { user: AuthUserDto }> {
    let user = null;
    if (tenantCode) {
      const tenant = await this.prisma.tenant.findUnique({ where: { code: tenantCode } });
      if (tenant && tenant.isActive) {
        user = await this.prisma.user.findUnique({
          where: { tenantId_phone: { tenantId: tenant.id, phone } },
        });
      }
    } else {
      // Platform-level accounts (PLATFORM_SUPER_ADMIN) have tenantId = null.
      user = await this.prisma.user.findFirst({ where: { phone, tenantId: null } });
    }

    if (!user || !user.isActive || !user.passwordHash) {
      await verifyPassword(DUMMY_PASSWORD_HASH, password);
      throw invalidCredentials();
    }

    const valid = await verifyPassword(user.passwordHash, password);
    if (!valid) {
      throw invalidCredentials();
    }

    const accessToken = signAccessToken(
      { sub: user.id, type: 'access' },
      this.config.accessSecret,
      this.config.accessTtl,
    );
    const refreshToken = generateRefreshToken();
    const expiresAt = new Date(Date.now() + parseDurationMs(this.config.refreshTtl));

    await this.prisma.refreshSession.create({
      data: {
        userId: user.id,
        tokenHash: hashRefreshToken(refreshToken),
        expiresAt,
      },
    });

    return { accessToken, refreshToken, user: toUserDto(user) };
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    const tokenHash = hashRefreshToken(refreshToken);
    const session = await this.prisma.refreshSession.findUnique({ where: { tokenHash } });

    if (!session) {
      throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Invalid refresh token');
    }

    if (session.revokedAt) {
      // A previously-rotated token was presented again — revoke all sessions.
      await this.prisma.refreshSession.updateMany({
        where: { userId: session.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      throw new AppError(401, 'REFRESH_TOKEN_REUSED', 'Refresh token reuse detected');
    }

    if (session.expiresAt <= new Date()) {
      throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Invalid refresh token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: session.userId },
      include: { tenant: { select: { isActive: true } } },
    });
    if (!user || !user.isActive || (user.tenantId !== null && user.tenant?.isActive !== true)) {
      await this.prisma.refreshSession.updateMany({
        where: { userId: session.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Invalid refresh token');
    }

    const accessToken = signAccessToken(
      { sub: user.id, type: 'access' },
      this.config.accessSecret,
      this.config.accessTtl,
    );
    const newRefreshToken = generateRefreshToken();
    const expiresAt = new Date(Date.now() + parseDurationMs(this.config.refreshTtl));

    try {
      // Revoke-and-replace is one transaction: a create failure leaves the old
      // refresh token usable instead of stranding the client between states.
      await this.prisma.$transaction(async (tx) => {
        const revoke = await tx.refreshSession.updateMany({
          where: { id: session.id, revokedAt: null },
          data: { revokedAt: new Date() },
        });
        if (revoke.count === 0) {
          throw new AppError(401, 'REFRESH_TOKEN_REUSED', 'Refresh token reuse detected');
        }
        await tx.refreshSession.create({
          data: {
            userId: user.id,
            tokenHash: hashRefreshToken(newRefreshToken),
            expiresAt,
          },
        });
      });
    } catch (error) {
      if (!(error instanceof AppError) || error.code !== 'REFRESH_TOKEN_REUSED') throw error;
      await this.prisma.refreshSession.updateMany({
        where: { userId: session.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      throw error;
    }

    return { accessToken, refreshToken: newRefreshToken };
  }

  async logout(refreshToken: string, deviceId?: string): Promise<void> {
    const tokenHash = hashRefreshToken(refreshToken);
    const session = await this.prisma.refreshSession.findUnique({ where: { tokenHash } });
    if (!session) {
      return;
    }
    const revokeSession = this.prisma.refreshSession.update({
      where: { id: session.id },
      data: { revokedAt: new Date() },
    });
    if (!deviceId) {
      await revokeSession;
      return;
    }
    await this.prisma.$transaction([
      revokeSession,
      this.prisma.deviceToken.updateMany({
        where: {
          userId: session.userId,
          isActive: true,
          OR: [{ deviceId }, { deviceId: null }],
        },
        data: { isActive: false },
      }),
    ]);
  }

  async logoutAll(userId: string): Promise<void> {
    await this.prisma.refreshSession.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async getUserById(userId: string): Promise<AuthUserDto> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.isActive) {
      throw new AppError(401, 'UNAUTHORIZED', 'User not found or inactive');
    }
    return toUserDto(user);
  }
}
