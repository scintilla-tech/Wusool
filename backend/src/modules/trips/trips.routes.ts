import type { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { AppError } from '../../utils/appError';
import { TripService } from './trips.service';
import { tripCreateSchema } from './trips.schemas';
import type { TripService as TripServiceType } from './trips.service';

function tenantOf(req: import('express').Request): string {
  const tenantId = req.auth?.tenantId;
  if (!tenantId) throw new AppError(403, 'TENANT_REQUIRED', 'Tenant scope required');
  return tenantId;
}

/** Admin-facing trip management. */
export function createTripsRouter(deps: ScopeDeps & { tripService?: TripServiceType }): Router {
  const router = createScopedRouter(deps, ['UNIVERSITY_ADMIN']);
  const service = deps.tripService ?? new TripService(deps.prisma);

  router.get(
    '/',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.listTrips(tenantOf(req)) });
    }),
  );

  router.post(
    '/',
    validate({ body: tripCreateSchema }),
    asyncHandler(async (req, res) => {
      res
        .status(201)
        .json({ success: true, data: await service.createTrip(tenantOf(req), req.body) });
    }),
  );

  return router;
}
