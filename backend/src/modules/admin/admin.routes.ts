import type { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { AdminService } from './admin.service';

export function createAdminRouter(deps: ScopeDeps): Router {
  const router = createScopedRouter(deps, ['UNIVERSITY_ADMIN']);
  const service = new AdminService(deps.prisma);

  router.get(
    '/dashboard',
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      res.json({ success: true, data: await service.getDashboard(tenantId) });
    }),
  );

  return router;
}
