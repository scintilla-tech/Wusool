import type { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { TripService } from './trips.service';
import { tripStudentStatusSchema } from './trips.schemas';

/** Driver-facing trip workflow. */
export function createDriverRouter(deps: ScopeDeps): Router {
  const router = createScopedRouter(deps, ['DRIVER']);
  const service = new TripService(deps.prisma);

  router.get(
    '/today',
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.getDriverToday(tenantId, req.auth?.userId as string);
      res.json({ success: true, data });
    }),
  );

  router.post(
    '/:tripId/start',
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.startTrip(tenantId, req.auth?.userId as string, req.params.tripId);
      res.json({ success: true, data });
    }),
  );

  router.patch(
    '/:tripId/students/:studentProfileId',
    validate({ body: tripStudentStatusSchema }),
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.setStudentStatus(
        tenantId,
        req.auth?.userId as string,
        req.params.tripId,
        req.params.studentProfileId,
        req.body.status,
      );
      res.json({ success: true, data });
    }),
  );

  router.post(
    '/:tripId/complete',
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.completeTrip(
        tenantId,
        req.auth?.userId as string,
        req.params.tripId,
      );
      res.json({ success: true, data });
    }),
  );

  return router;
}
