import type { PrismaClient } from '@prisma/client';
import type { RequestHandler } from 'express';
import { asyncHandler } from '../utils/asyncHandler';
import { verifyAccessToken } from '../utils/token';
import { AppError } from '../utils/appError';

export interface AuthenticateDeps {
  prisma: PrismaClient;
  accessSecret: string;
}

/**
 * Verifies the Bearer access token and attaches `req.auth` from the
 * authenticated server context (fresh user lookup — never trusts tenantId/role
 * from the token or the client).
 */
export function createAuthenticate({ prisma, accessSecret }: AuthenticateDeps): RequestHandler {
  return asyncHandler(async (req, _res, next) => {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
    }

    const token = header.slice('Bearer '.length).trim();
    if (token.length === 0) {
      throw new AppError(401, 'UNAUTHORIZED', 'Authentication required');
    }

    let payload;
    try {
      payload = verifyAccessToken(token, accessSecret);
    } catch {
      throw new AppError(401, 'UNAUTHORIZED', 'Invalid or expired token');
    }

    const user = await prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user || !user.isActive) {
      throw new AppError(401, 'UNAUTHORIZED', 'User not found or inactive');
    }

    req.auth = { userId: user.id, tenantId: user.tenantId, role: user.role };
    next();
  });
}
