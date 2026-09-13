import type { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { SupervisorService } from './supervisor.service';

export function createSupervisorRouter(deps: ScopeDeps): Router {
  const router = createScopedRouter(deps, ['SUPERVISOR', 'FIELD_SUPERVISOR']);
  const service = new SupervisorService(deps.prisma);

  router.get(
    '/buses',
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.getMyBuses(tenantId, req.auth?.userId as string, req.auth!.role);
      res.json({ success: true, data });
    }),
  );

  return router;
}
