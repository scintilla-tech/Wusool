import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createAuthenticate } from '../../middlewares/authenticate';
import { authorize } from '../../middlewares/authorize';
import { PlatformService } from './platform.service';
import { tenantCreateSchema, tenantUpdateSchema } from './platform.schemas';
import type { ScopeDeps } from '../../middlewares/scope';

/** Platform-level administration. No tenant scope (PLATFORM_SUPER_ADMIN has tenantId = null). */
export function createPlatformRouter(deps: ScopeDeps): Router {
  const router = Router();
  const service = new PlatformService(deps.prisma);

  router.use(
    createAuthenticate({ prisma: deps.prisma, accessSecret: deps.config.JWT_ACCESS_SECRET }),
    authorize('PLATFORM_SUPER_ADMIN'),
  );

  router.get(
    '/tenants',
    asyncHandler(async (_req, res) => {
      res.json({ success: true, data: await service.listTenants() });
    }),
  );

  router.post(
    '/tenants',
    validate({ body: tenantCreateSchema }),
    asyncHandler(async (req, res) => {
      res.status(201).json({ success: true, data: await service.createTenant(req.body) });
    }),
  );

  router.patch(
    '/tenants/:id',
    validate({ body: tenantUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.updateTenant(req.params.id, req.body) });
    }),
  );

  return router;
}
