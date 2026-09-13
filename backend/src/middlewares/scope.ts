import { Router } from 'express';
import type { PrismaClient, Role } from '@prisma/client';
import type { EnvConfig } from '../config/env';
import { createAuthenticate } from './authenticate';
import { authorize } from './authorize';
import { requireTenant } from './requireTenant';

export interface ScopeDeps {
  prisma: PrismaClient;
  config: EnvConfig;
}

/**
 * Creates a router pre-wired with authenticate + role authorization + tenant scope.
 */
export function createScopedRouter(deps: ScopeDeps, roles: Role[]): Router {
  const router = Router();
  router.use(
    createAuthenticate({ prisma: deps.prisma, accessSecret: deps.config.JWT_ACCESS_SECRET }),
    authorize(...roles),
    requireTenant,
  );
  return router;
}
