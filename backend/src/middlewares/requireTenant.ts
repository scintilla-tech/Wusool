import type { RequestHandler } from 'express';
import { AppError } from '../utils/appError';

/**
 * Requires a university tenant scope (req.auth.tenantId must be present).
 * Rejects platform-level principals (tenantId === null).
 */
export const requireTenant: RequestHandler = (req, _res, next) => {
  if (!req.auth?.tenantId) {
    next(new AppError(403, 'TENANT_REQUIRED', 'This action requires a university tenant scope'));
    return;
  }
  next();
};
