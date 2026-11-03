import type { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { AppError } from '../../utils/appError';
import { paginationSchema } from '../../validation/common';
import { AssignmentsService } from './assignments.service';
import {
  assignDriverSchema,
  assignStudentSchema,
  assignStudentsToRouteSchema,
  assignSupervisorSchema,
} from './assignments.schemas';

function tenantOf(req: import('express').Request): string {
  const tenantId = req.auth?.tenantId;
  if (!tenantId) throw new AppError(403, 'TENANT_REQUIRED', 'Tenant scope required');
  return tenantId;
}

function pageParams(req: import('express').Request): { page: number; limit: number } {
  const q = req.query as unknown as { page: number; limit: number };
  return { page: q.page, limit: q.limit };
}

export function createAssignmentsRouter(deps: ScopeDeps): Router {
  const router = createScopedRouter(deps, ['UNIVERSITY_ADMIN']);
  const service = new AssignmentsService(deps.prisma);

  // Students
  router.get(
    '/students',
    validate({ query: paginationSchema }),
    asyncHandler(async (req, res) => {
      const { page, limit } = pageParams(req);
      res.json({
        success: true,
        data: await service.listStudentAssignments(tenantOf(req), page, limit),
      });
    }),
  );
  router.post(
    '/students',
    validate({ body: assignStudentSchema }),
    asyncHandler(async (req, res) => {
      res
        .status(201)
        .json({ success: true, data: await service.assignStudent(tenantOf(req), req.body) });
    }),
  );
  router.post(
    '/students/batch',
    validate({ body: assignStudentsToRouteSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.assignStudentsToRoute(tenantOf(req), req.body),
      });
    }),
  );
  router.delete(
    '/students/:studentProfileId',
    asyncHandler(async (req, res) => {
      await service.unassignStudent(tenantOf(req), req.params.studentProfileId);
      res.json({ success: true, data: {} });
    }),
  );

  // Drivers
  router.get(
    '/drivers',
    validate({ query: paginationSchema }),
    asyncHandler(async (req, res) => {
      const { page, limit } = pageParams(req);
      res.json({
        success: true,
        data: await service.listDriverAssignments(tenantOf(req), page, limit),
      });
    }),
  );
  router.post(
    '/drivers',
    validate({ body: assignDriverSchema }),
    asyncHandler(async (req, res) => {
      res
        .status(201)
        .json({ success: true, data: await service.assignDriver(tenantOf(req), req.body) });
    }),
  );
  router.delete(
    '/drivers/:busId',
    asyncHandler(async (req, res) => {
      await service.unassignDriver(tenantOf(req), req.params.busId);
      res.json({ success: true, data: {} });
    }),
  );

  // Supervisors
  router.get(
    '/supervisors',
    validate({ query: paginationSchema }),
    asyncHandler(async (req, res) => {
      const { page, limit } = pageParams(req);
      res.json({
        success: true,
        data: await service.listSupervisorAssignments(tenantOf(req), page, limit),
      });
    }),
  );
  router.post(
    '/supervisors',
    validate({ body: assignSupervisorSchema }),
    asyncHandler(async (req, res) => {
      res
        .status(201)
        .json({ success: true, data: await service.assignSupervisor(tenantOf(req), req.body) });
    }),
  );
  router.delete(
    '/supervisors/:busId',
    asyncHandler(async (req, res) => {
      await service.unassignSupervisor(tenantOf(req), req.params.busId);
      res.json({ success: true, data: {} });
    }),
  );

  return router;
}
