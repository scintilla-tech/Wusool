import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { createAuthenticate } from '../../middlewares/authenticate';
import { MockPushProvider } from '../../providers/notifications';
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
    asyncHandler(async (req, res) => {
      const page = Number((req.query as { page?: number }).page ?? 1);
      const limit = Number((req.query as { limit?: number }).limit ?? 20);
      res.json({
        success: true,
        data: await service.listMine(req.auth?.userId as string, page, limit),
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
