import type { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { AttendanceService } from './attendance.service';
import { attendanceDirectionSchema, setAttendanceIntentSchema } from './attendance.schemas';
import type { TripEventBus } from '../trips/trip-events';

export function createAttendanceRouter(deps: ScopeDeps & { tripEvents?: TripEventBus }): Router {
  const router = createScopedRouter(deps, ['STUDENT']);
  const service = new AttendanceService(deps.prisma, deps.tripEvents);

  router.get(
    '/today',
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.getTodayForUser(tenantId, req.auth?.userId as string);
      res.json({ success: true, data });
    }),
  );

  router.put(
    '/today',
    validate({ body: setAttendanceIntentSchema }),
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.setIntentForUser(
        tenantId,
        req.auth?.userId as string,
        req.body.direction ?? 'OUTBOUND',
        req.body,
      );
      res.json({ success: true, data });
    }),
  );

  router.put(
    '/today/:direction',
    validate({ body: setAttendanceIntentSchema }),
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const direction = attendanceDirectionSchema.parse(req.params.direction);
      const data = await service.setIntentForUser(
        tenantId,
        req.auth?.userId as string,
        direction,
        req.body,
      );
      res.json({ success: true, data });
    }),
  );

  return router;
}
