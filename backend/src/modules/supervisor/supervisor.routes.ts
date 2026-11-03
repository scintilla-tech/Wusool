import type { Request, Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { AppError } from '../../utils/appError';
import { calendarDaySchema, idSchema } from '../../validation/common';
import { createNotificationService } from '../notifications/notification.service';
import { CoverService } from './cover.service';
import { SupervisorService } from './supervisor.service';

const coverSchema = z
  .object({ driverProfileId: idSchema, date: calendarDaySchema.optional() })
  .strict();
const dayQuerySchema = z.object({ date: calendarDaySchema.optional() }).strict();

/** Only a bus's own supervisor picks a cover driver for it. */
function busSupervisor(req: Request): { tenantId: string; userId: string } {
  if (req.auth?.role !== 'SUPERVISOR') {
    throw new AppError(403, 'FORBIDDEN', 'Only bus supervisors choose cover drivers');
  }
  return { tenantId: req.auth.tenantId as string, userId: req.auth.userId };
}

export function createSupervisorRouter(deps: ScopeDeps): Router {
  const router = createScopedRouter(deps, ['SUPERVISOR', 'FIELD_SUPERVISOR']);
  const service = new SupervisorService(deps.prisma);
  const covers = new CoverService(deps.prisma, createNotificationService(deps.prisma));

  router.get(
    '/buses',
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.getMyBuses(tenantId, req.auth?.userId as string, req.auth!.role);
      res.json({ success: true, data });
    }),
  );

  router.get(
    '/buses/:busId/drivers',
    validate({ query: dayQuerySchema }),
    asyncHandler(async (req, res) => {
      const { tenantId, userId } = busSupervisor(req);
      const { date } = req.query as unknown as { date?: Date };
      res.json({
        success: true,
        data: { items: await covers.candidates(tenantId, userId, req.params.busId, date) },
      });
    }),
  );

  router.post(
    '/buses/:busId/cover',
    validate({ body: coverSchema }),
    asyncHandler(async (req, res) => {
      const { tenantId, userId } = busSupervisor(req);
      res.json({
        success: true,
        data: await covers.cover(
          tenantId,
          userId,
          req.params.busId,
          req.body.driverProfileId,
          req.body.date,
        ),
      });
    }),
  );

  return router;
}
