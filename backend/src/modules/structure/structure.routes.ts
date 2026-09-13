import type { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { AppError } from '../../utils/appError';
import { StructureService } from './structure.service';
import {
  branchCreateSchema,
  branchUpdateSchema,
  busCreateSchema,
  busUpdateSchema,
  listQuerySchema,
  neighborhoodCreateSchema,
  neighborhoodUpdateSchema,
  routeCreateSchema,
  routeStopsUpdateSchema,
  routeUpdateSchema,
} from './structure.schemas';

function tenantOf(req: import('express').Request): string {
  const tenantId = req.auth?.tenantId;
  if (!tenantId) throw new AppError(403, 'TENANT_REQUIRED', 'Tenant scope required');
  return tenantId;
}

export function createStructureRouter(deps: ScopeDeps): Router {
  const router = createScopedRouter(deps, ['UNIVERSITY_ADMIN']);
  const service = new StructureService(deps.prisma);

  const listParams = (req: import('express').Request) => {
    const q = req.query as unknown as { page: number; limit: number; active?: string };
    return { page: q.page, limit: q.limit, activeOnly: q.active === 'true' };
  };

  // Branches
  router.get(
    '/branches',
    validate({ query: listQuerySchema }),
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.listBranches(tenantOf(req), listParams(req)) });
    }),
  );
  router.post(
    '/branches',
    validate({ body: branchCreateSchema }),
    asyncHandler(async (req, res) => {
      res
        .status(201)
        .json({ success: true, data: await service.createBranch(tenantOf(req), req.body) });
    }),
  );
  router.patch(
    '/branches/:id',
    validate({ body: branchUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.updateBranch(tenantOf(req), req.params.id, req.body),
      });
    }),
  );
  router.delete(
    '/branches/:id',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.archiveBranch(tenantOf(req), req.params.id) });
    }),
  );

  // Neighborhoods
  router.get(
    '/neighborhoods',
    validate({ query: listQuerySchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.listNeighborhoods(tenantOf(req), listParams(req)),
      });
    }),
  );
  router.post(
    '/neighborhoods',
    validate({ body: neighborhoodCreateSchema }),
    asyncHandler(async (req, res) => {
      res
        .status(201)
        .json({ success: true, data: await service.createNeighborhood(tenantOf(req), req.body) });
    }),
  );
  router.patch(
    '/neighborhoods/:id',
    validate({ body: neighborhoodUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.updateNeighborhood(tenantOf(req), req.params.id, req.body),
      });
    }),
  );
  router.delete(
    '/neighborhoods/:id',
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.archiveNeighborhood(tenantOf(req), req.params.id),
      });
    }),
  );

  // Buses
  router.get(
    '/buses',
    validate({ query: listQuerySchema }),
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.listBuses(tenantOf(req), listParams(req)) });
    }),
  );
  router.post(
    '/buses',
    validate({ body: busCreateSchema }),
    asyncHandler(async (req, res) => {
      res
        .status(201)
        .json({ success: true, data: await service.createBus(tenantOf(req), req.body) });
    }),
  );
  router.patch(
    '/buses/:id',
    validate({ body: busUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.updateBus(tenantOf(req), req.params.id, req.body),
      });
    }),
  );
  router.delete(
    '/buses/:id',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.archiveBus(tenantOf(req), req.params.id) });
    }),
  );

  // Routes
  router.get(
    '/routes',
    validate({ query: listQuerySchema }),
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.listRoutes(tenantOf(req), listParams(req)) });
    }),
  );
  router.get(
    '/routes/:id',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.getRoute(tenantOf(req), req.params.id) });
    }),
  );
  router.post(
    '/routes',
    validate({ body: routeCreateSchema }),
    asyncHandler(async (req, res) => {
      res
        .status(201)
        .json({ success: true, data: await service.createRoute(tenantOf(req), req.body) });
    }),
  );
  router.patch(
    '/routes/:id',
    validate({ body: routeUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.updateRoute(tenantOf(req), req.params.id, req.body),
      });
    }),
  );
  router.delete(
    '/routes/:id',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.archiveRoute(tenantOf(req), req.params.id) });
    }),
  );
  router.put(
    '/routes/:id/stops',
    validate({ body: routeStopsUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.setRouteStops(tenantOf(req), req.params.id, req.body.stops),
      });
    }),
  );

  return router;
}
