import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { createAuthenticate } from '../../middlewares/authenticate';
import { validate } from '../../middlewares/validate';
import { MockPushProvider } from '../../providers/notifications';
import { paginationSchema } from '../../validation/common';
import { NotificationService } from './notification.service';
import type { ScopeDeps } from '../../middlewares/scope';

export function createNotificationsRouter(deps: ScopeDeps): Router {
  const router = Router();
  const authenticate = createAuthenticate({
    prisma: deps.prisma,
    accessSecret: deps.config.JWT_ACCESS_SECRET,
  });
  const service = new NotificationService(deps.prisma, new MockPushProvider());

  router.get(
    '/',
    authenticate,
    validate({ query: paginationSchema }),
    asyncHandler(async (req, res) => {
      const q = req.query as unknown as { page: number; limit: number };
      res.json({
        success: true,
        data: await service.listMine(req.auth?.userId as string, q.page, q.limit),
      });
    }),
  );

  router.patch(
    '/:id/read',
    authenticate,
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.markRead(req.auth?.userId as string, req.params.id),
      });
    }),
  );

  return router;
}
