import type { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { TripService } from './trips.service';
import { tripStudentStatusSchema } from './trips.schemas';
import type { TripService as TripServiceType } from './trips.service';
import { AttendanceService } from '../attendance/attendance.service';
import { closeAttendanceSchema, driverAttendanceSchema } from '../attendance/attendance.schemas';
import type { TripEventBus } from './trip-events';

/** Driver-facing trip workflow. */
export function createDriverRouter(
  deps: ScopeDeps & { tripService?: TripServiceType; tripEvents?: TripEventBus },
): Router {
  const router = createScopedRouter(deps, ['DRIVER']);
  const service = deps.tripService ?? new TripService(deps.prisma);
  const attendance = new AttendanceService(deps.prisma, deps.tripEvents);

  router.get(
    '/today',
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.getDriverToday(tenantId, req.auth?.userId as string);
      res.json({ success: true, data });
    }),
  );

  router.get(
    '/today/trips',
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.getDriverTodayTrips(tenantId, req.auth?.userId as string);
      res.json({ success: true, data });
    }),
  );

  router.put(
    '/:tripId/attendance/:studentProfileId',
    validate({ body: driverAttendanceSchema }),
    asyncHandler(async (req, res) => {
      const data = await attendance.setIntentByDriver(
        req.auth?.tenantId as string,
        req.auth?.userId as string,
        req.params.tripId,
        req.params.studentProfileId,
        req.body,
      );
      res.json({ success: true, data });
    }),
  );

  router.post(
    '/:tripId/attendance/close',
    validate({ body: closeAttendanceSchema }),
    asyncHandler(async (req, res) => {
      const data = await attendance.closeByDriver(
        req.auth?.tenantId as string,
        req.auth?.userId as string,
        req.params.tripId,
      );
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
