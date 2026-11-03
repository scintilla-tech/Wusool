import type { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { TripService } from './trips.service';
import { driverTripCreateSchema, tripStudentStatusSchema } from './trips.schemas';
import type { TripService as TripServiceType } from './trips.service';
import { AttendanceService } from '../attendance/attendance.service';
import { closeAttendanceSchema, driverAttendanceSchema } from '../attendance/attendance.schemas';
import type { TripEventBus } from './trip-events';
import { z } from 'zod';
import { idSchema } from '../../validation/common';
import { createNotificationService } from '../notifications/notification.service';
import { StructureService } from '../structure/structure.service';
import { neighborhoodCreateSchema, routeStopIdsSchema } from '../structure/structure.schemas';
import { DriverRouteService } from './driver-route.service';

const placeName = neighborhoodCreateSchema.shape.name;
const driverRouteCreateSchema = z
  .object({
    name: placeName,
    branchId: idSchema.nullable().optional(),
    stopIds: routeStopIdsSchema.min(1),
  })
  .strict();
const driverRouteUpdateSchema = driverRouteCreateSchema.partial().strict();

/** Driver-facing trip workflow. */
export function createDriverRouter(
  deps: ScopeDeps & { tripService?: TripServiceType; tripEvents?: TripEventBus },
): Router {
  const router = createScopedRouter(deps, ['DRIVER']);
  const service = deps.tripService ?? new TripService(deps.prisma);
  const attendance = new AttendanceService(deps.prisma, deps.tripEvents);
  const notifications = createNotificationService(deps.prisma);
  const routes = new DriverRouteService(
    deps.prisma,
    new StructureService(deps.prisma),
    notifications,
  );
  const tenantOf = (req: import('express').Request) => req.auth?.tenantId as string;
  const userOf = (req: import('express').Request) => req.auth?.userId as string;

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

  router.get(
    '/bus',
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.getDriverBus(tenantId, req.auth?.userId as string);
      res.json({ success: true, data });
    }),
  );

  router.post(
    '/trips',
    validate({ body: driverTripCreateSchema }),
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      const data = await service.createTripByDriver(tenantId, req.auth?.userId as string, req.body);
      res.status(201).json({ success: true, data });
    }),
  );

  router.get(
    '/route-options',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await routes.options(tenantOf(req)) });
    }),
  );

  router.post(
    '/neighborhoods',
    validate({ body: neighborhoodCreateSchema.pick({ name: true }).strict() }),
    asyncHandler(async (req, res) => {
      res
        .status(201)
        .json({ success: true, data: await routes.addNeighborhood(tenantOf(req), req.body.name) });
    }),
  );

  router.post(
    '/route',
    validate({ body: driverRouteCreateSchema }),
    asyncHandler(async (req, res) => {
      res
        .status(201)
        .json({ success: true, data: await routes.create(tenantOf(req), userOf(req), req.body) });
    }),
  );

  router.patch(
    '/route',
    validate({ body: driverRouteUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await routes.update(tenantOf(req), userOf(req), req.body) });
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
