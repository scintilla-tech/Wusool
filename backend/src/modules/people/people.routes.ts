import type { Request, Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { AppError } from '../../utils/appError';
import { PeopleService } from './people.service';
import { peopleListQuerySchema, personUpdateSchema, type PeopleListQuery } from './people.schemas';

function tenantOf(req: Request): string {
  const tenantId = req.auth?.tenantId;
  if (!tenantId) throw new AppError(403, 'TENANT_REQUIRED', 'Tenant scope required');
  return tenantId;
}

function actorOf(req: Request): string {
  return req.auth?.userId as string;
}

/** The university admin's directory of students and staff. */
export function createPeopleRouter(deps: ScopeDeps): Router {
  const router = createScopedRouter(deps, ['UNIVERSITY_ADMIN']);
  const service = new PeopleService(deps.prisma);

  router.get(
    '/',
    validate({ query: peopleListQuerySchema }),
    asyncHandler(async (req, res) => {
      const query = req.query as unknown as PeopleListQuery;
      res.json({ success: true, data: await service.list(tenantOf(req), query) });
    }),
  );

  router.get(
    '/:id',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.get(tenantOf(req), req.params.id) });
    }),
  );

  router.put(
    '/:id',
    validate({ body: personUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.update(tenantOf(req), actorOf(req), req.params.id, req.body.row),
      });
    }),
  );

  router.post(
    '/:id/disable',
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.disable(tenantOf(req), actorOf(req), req.params.id),
      });
    }),
  );

  router.post(
    '/:id/enable',
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.enable(tenantOf(req), actorOf(req), req.params.id),
      });
    }),
  );

  return router;
}
