import type { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { AppError } from '../../utils/appError';
import { StudentsService } from './students.service';
import {
  studentCreateSchema,
  studentListQuerySchema,
  studentUpdateSchema,
} from './students.schemas';

function tenantOf(req: import('express').Request): string {
  const tenantId = req.auth?.tenantId;
  if (!tenantId) throw new AppError(403, 'TENANT_REQUIRED', 'Tenant scope required');
  return tenantId;
}

export function createStudentsRouter(deps: ScopeDeps): Router {
  const router = createScopedRouter(deps, ['UNIVERSITY_ADMIN']);
  const service = new StudentsService(deps.prisma);

  router.get(
    '/',
    validate({ query: studentListQuerySchema }),
    asyncHandler(async (req, res) => {
      const q = req.query as unknown as { page: number; limit: number };
      res.json({ success: true, data: await service.list(tenantOf(req), q.page, q.limit) });
    }),
  );

  router.get(
    '/:id',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.get(tenantOf(req), req.params.id) });
    }),
  );

  router.post(
    '/',
    validate({ body: studentCreateSchema }),
    asyncHandler(async (req, res) => {
      res.status(201).json({ success: true, data: await service.create(tenantOf(req), req.body) });
    }),
  );

  router.patch(
    '/:id',
    validate({ body: studentUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.update(tenantOf(req), req.params.id, req.body),
      });
    }),
  );

  router.delete(
    '/:id',
    asyncHandler(async (req, res) => {
      await service.deactivate(tenantOf(req), req.params.id);
      res.json({ success: true, data: {} });
    }),
  );

  return router;
}
