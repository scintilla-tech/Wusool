import { Router } from 'express';
import type { PrismaClient } from '@prisma/client';
import type { EnvConfig } from '../../config/env';
import { validate } from '../../middlewares/validate';
import { createAuthenticate } from '../../middlewares/authenticate';
import { createRateLimiter, loginKeyGenerator } from '../../middlewares/rateLimit';
import { AuthService } from './auth.service';
import { createAuthController } from './auth.controller';
import { loginSchema, refreshSchema } from './auth.schemas';

export interface AuthRouterDeps {
  prisma: PrismaClient;
  config: EnvConfig;
}

export function createAuthRouter({ prisma, config }: AuthRouterDeps): Router {
  const service = new AuthService(prisma, {
    accessSecret: config.JWT_ACCESS_SECRET,
    accessTtl: config.JWT_ACCESS_TTL,
    refreshTtl: config.JWT_REFRESH_TTL,
  });
  const controller = createAuthController(service);
  const authenticate = createAuthenticate({ prisma, accessSecret: config.JWT_ACCESS_SECRET });

  const loginLimiter = createRateLimiter({
    windowMs: 15 * 60 * 1000,
    limit: config.LOGIN_RATE_LIMIT,
    keyGenerator: loginKeyGenerator,
  });
  const refreshLimiter = createRateLimiter({ windowMs: 15 * 60 * 1000, limit: 60 });
  const logoutLimiter = createRateLimiter({ windowMs: 15 * 60 * 1000, limit: 60 });

  const router = Router();

  router.post('/login', loginLimiter, validate({ body: loginSchema }), controller.login);
  router.post('/refresh', refreshLimiter, validate({ body: refreshSchema }), controller.refresh);
  router.post('/logout', logoutLimiter, validate({ body: refreshSchema }), controller.logout);
  router.get('/me', authenticate, controller.me);

  return router;
}
