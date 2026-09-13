import { Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { asyncHandler } from '../../utils/asyncHandler';
import { createAuthenticate } from '../../middlewares/authenticate';
import { requireTenant } from '../../middlewares/requireTenant';
import { createRateLimiter } from '../../middlewares/rateLimit';
import { AppError } from '../../utils/appError';
import { DocumentsService } from './documents.service';
import type { ScopeDeps } from '../../middlewares/scope';
import type { StorageProvider } from '../../providers/storage';

export interface DocumentsDeps extends ScopeDeps {
  storage: StorageProvider;
}

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

const uploadBodySchema = z.object({ documentType: z.string().trim().min(1).max(64) }).strict();

export function createDocumentsRouter(deps: DocumentsDeps): Router {
  const router = Router();
  const service = new DocumentsService(deps.prisma, deps.storage);
  const authenticate = createAuthenticate({
    prisma: deps.prisma,
    accessSecret: deps.config.JWT_ACCESS_SECRET,
  });
  const uploadLimiter = createRateLimiter({ windowMs: 15 * 60 * 1000, limit: 30 });

  router.post(
    '/',
    authenticate,
    requireTenant,
    uploadLimiter,
    upload.single('file'),
    asyncHandler(async (req, res) => {
      if (!req.file) throw new AppError(400, 'NO_FILE', 'File is required');
      const body = uploadBodySchema.parse(req.body);
      const data = await service.upload(
        req.auth?.tenantId as string,
        req.auth?.userId as string,
        req.file.buffer,
        body.documentType,
      );
      res.status(201).json({ success: true, data });
    }),
  );

  router.get(
    '/:id/url',
    authenticate,
    requireTenant,
    asyncHandler(async (req, res) => {
      const data = await service.getSignedUrl(
        req.auth?.tenantId as string,
        req.auth?.userId as string,
        req.auth!.role,
        req.params.id,
      );
      res.json({ success: true, data });
    }),
  );

  router.get(
    '/:id/file',
    authenticate,
    requireTenant,
    asyncHandler(async (req, res) => {
      const { mimeType, buffer } = await service.readAuthorized(
        req.auth?.tenantId as string,
        req.auth?.userId as string,
        req.auth!.role,
        req.params.id,
      );
      res.setHeader('Content-Type', mimeType ?? 'application/octet-stream');
      res.setHeader('Content-Disposition', 'inline');
      res.send(buffer);
    }),
  );

  return router;
}
