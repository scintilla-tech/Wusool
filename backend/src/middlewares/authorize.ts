import type { Role } from '@prisma/client';
import type { RequestHandler } from 'express';
import { AppError } from '../utils/appError';

/**
 * Role-based authorization. Requires `req.auth` (set by `createAuthenticate`).
 */
export function authorize(...roles: Role[]): RequestHandler {
  return (req, _res, next) => {
    if (!req.auth) {
      next(new AppError(401, 'UNAUTHORIZED', 'Authentication required'));
      return;
    }
    if (roles.length > 0 && !roles.includes(req.auth.role)) {
      next(new AppError(403, 'FORBIDDEN', 'Insufficient permissions'));
      return;
    }
    next();
  };
}
