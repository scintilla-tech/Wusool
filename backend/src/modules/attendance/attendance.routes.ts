import type { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { AttendanceService } from './attendance.service';
import { setAttendanceIntentSchema } from './attendance.schemas';

export function createAttendanceRouter(deps: ScopeDeps): Router {
  const router = createScopedRouter(deps, ['STUDENT']);
  const service = new AttendanceService(deps.prisma, deps.config.ATTENDANCE_CUTOFF);

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
        req.body.intent,
        req.body.note,
      );
      res.json({ success: true, data });
    }),
  );

  return router;
}
