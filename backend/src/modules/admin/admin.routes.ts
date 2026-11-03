import type { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { calendarDaySchema } from '../../validation/common';
import { AdminService } from './admin.service';
import { HolidayService } from './holiday.service';

const settingsSchema = z
  .object({
    autoTrips: z.boolean().optional(),
    /** Riyadh time, 24-hour. */
    autoTripTime: z
      .string()
      .regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Use HH:MM')
      .optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0, 'Nothing to change');

const holidayName = z.string().trim().min(1).max(100);
const holidayCreateSchema = z
  .object({ name: holidayName, startDate: calendarDaySchema, endDate: calendarDaySchema })
  .strict();
const holidayUpdateSchema = holidayCreateSchema.partial().strict();

export function createAdminRouter(deps: ScopeDeps): Router {
  const router = createScopedRouter(deps, ['UNIVERSITY_ADMIN']);
  const service = new AdminService(deps.prisma);
  const holidays = new HolidayService(deps.prisma);
  const tenantOf = (req: import('express').Request) => req.auth?.tenantId as string;
  const actorOf = (req: import('express').Request) => req.auth?.userId as string;

  router.get(
    '/dashboard',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.getDashboard(tenantOf(req)) });
    }),
  );

  router.get(
    '/settings',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.getSettings(tenantOf(req)) });
    }),
  );

  router.patch(
    '/settings',
    validate({ body: settingsSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.updateSettings(tenantOf(req), actorOf(req), req.body),
      });
    }),
  );

  router.get(
    '/holidays',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: { items: await holidays.list(tenantOf(req)) } });
    }),
  );

  router.post(
    '/holidays',
    validate({ body: holidayCreateSchema }),
    asyncHandler(async (req, res) => {
      res.status(201).json({
        success: true,
        data: await holidays.create(tenantOf(req), actorOf(req), req.body),
      });
    }),
  );

  router.patch(
    '/holidays/:id',
    validate({ body: holidayUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await holidays.update(tenantOf(req), actorOf(req), req.params.id, req.body),
      });
    }),
  );

  router.delete(
    '/holidays/:id',
    asyncHandler(async (req, res) => {
      await holidays.remove(tenantOf(req), actorOf(req), req.params.id);
      res.json({ success: true, data: {} });
    }),
  );

  return router;
}
