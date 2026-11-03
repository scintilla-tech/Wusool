import { Router } from 'express';
import type { PrismaClient } from '@prisma/client';
import type { EnvConfig } from '../../config/env';
import { validate } from '../../middlewares/validate';
import { createAuthenticate } from '../../middlewares/authenticate';
import { createRateLimiter, loginKeyGenerator } from '../../middlewares/rateLimit';
import { MockOtpProvider } from '../../providers/otp';
import { OtpService } from '../otp/otp.service';
import { AuthService } from './auth.service';
import { ActivationService } from './activation.service';
import { createActivationController, createAuthController } from './auth.controller';
import {
  activationCompleteSchema,
  activationRequestSchema,
  loginSchema,
  logoutSchema,
  refreshSchema,
} from './auth.schemas';

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
  const activation = createActivationController(
    new ActivationService(
      prisma,
      new OtpService(new MockOtpProvider()),
      service,
      config.NODE_ENV === 'development',
    ),
  );
  const authenticate = createAuthenticate({ prisma, accessSecret: config.JWT_ACCESS_SECRET });

  const loginLimiter = createRateLimiter({
    windowMs: 15 * 60 * 1000,
    limit: config.LOGIN_RATE_LIMIT,
    keyGenerator: loginKeyGenerator,
  });
  // Each code request sends an SMS, so allow only a few per account.
  const activationRequestLimiter = createRateLimiter({
    windowMs: 15 * 60 * 1000,
    limit: 5,
    keyGenerator: loginKeyGenerator,
  });
  const activationCompleteLimiter = createRateLimiter({
    windowMs: 15 * 60 * 1000,
    limit: config.LOGIN_RATE_LIMIT,
    keyGenerator: loginKeyGenerator,
  });
  const refreshLimiter = createRateLimiter({ windowMs: 15 * 60 * 1000, limit: 60 });
  const logoutLimiter = createRateLimiter({ windowMs: 15 * 60 * 1000, limit: 60 });

  const router = Router();

  router.post('/login', loginLimiter, validate({ body: loginSchema }), controller.login);
  router.post(
    '/activation/request',
    activationRequestLimiter,
    validate({ body: activationRequestSchema }),
    activation.request,
  );
  router.post(
    '/activation/complete',
    activationCompleteLimiter,
    validate({ body: activationCompleteSchema }),
    activation.complete,
  );
  router.post('/refresh', refreshLimiter, validate({ body: refreshSchema }), controller.refresh);
  router.post('/logout', logoutLimiter, validate({ body: logoutSchema }), controller.logout);
  router.post('/logout-all', authenticate, controller.logoutAll);
  router.get('/me', authenticate, controller.me);

  return router;
}
