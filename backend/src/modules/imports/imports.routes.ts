import { Router, type Request, type RequestHandler } from 'express';
import multer from 'multer';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createScopedRouter, type ScopeDeps } from '../../middlewares/scope';
import { createRateLimiter } from '../../middlewares/rateLimit';
import { AppError } from '../../utils/appError';
import { TEMPLATE_SLUGS, templateCsv } from './imports.fields';
import { MAX_IMPORT_FILE_BYTES } from './imports.file';
import { ImportsService } from './imports.service';
import {
  checkRowsSchema,
  draftCreateSchema,
  draftListQuerySchema,
  draftUpdateSchema,
  readFileFieldsSchema,
  submitRowsSchema,
  type CheckRowsInput,
  type DraftListQuery,
  type SubmitRowsInput,
} from './imports.schemas';

function tenantOf(req: Request): string {
  const tenantId = req.auth?.tenantId;
  if (!tenantId) throw new AppError(403, 'TENANT_REQUIRED', 'Tenant scope required');
  return tenantId;
}

function actorOf(req: Request): string {
  return req.auth?.userId as string;
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_IMPORT_FILE_BYTES, files: 1, fields: 4 },
  // Arabic file names arrive as UTF-8.
  defParamCharset: 'utf8',
}).single('file');

/** Runs the upload, turning size and shape errors into clear client errors. */
const receiveFile: RequestHandler = (req, res, next) => {
  upload(req, res, (error: unknown) => {
    if (error instanceof multer.MulterError) {
      next(
        error.code === 'LIMIT_FILE_SIZE'
          ? new AppError(413, 'FILE_TOO_LARGE', 'The file must be 2 MB or smaller')
          : new AppError(400, 'INVALID_UPLOAD', 'Send one file in the "file" field'),
      );
      return;
    }
    next(error);
  });
};

/** Blank spreadsheets to fill in. Public: they hold column headers only. */
export function createImportTemplatesRouter(): Router {
  const router = Router();

  router.get('/templates/:kind', (req, res) => {
    const role = TEMPLATE_SLUGS[req.params.kind];
    if (!role) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Template not found' },
      });
      return;
    }
    res
      .status(200)
      .type('text/csv; charset=utf-8')
      .attachment(`wusool-${req.params.kind}.csv`)
      .send(templateCsv(role));
  });

  return router;
}

export function createImportsRouter(deps: ScopeDeps): Router {
  const router = createScopedRouter(deps, ['UNIVERSITY_ADMIN']);
  const service = new ImportsService(deps.prisma);
  const fileLimiter = createRateLimiter({ windowMs: 15 * 60 * 1000, limit: 30 });

  router.post(
    '/read-file',
    fileLimiter,
    receiveFile,
    asyncHandler(async (req, res) => {
      if (!req.file) throw new AppError(400, 'NO_FILE', 'File is required');
      const fields = readFileFieldsSchema.parse(req.body);
      const fileName = req.file.originalname;
      const result = await service.readFile(tenantOf(req), fields.role, req.file.buffer, fileName);
      const name =
        fields.name ??
        (fileName
          .replace(/\.[^.]+$/, '')
          .trim()
          .slice(0, 120) ||
          'ملف');
      res.json({ success: true, data: { name, ...result } });
    }),
  );

  router.post(
    '/check',
    validate({ body: checkRowsSchema }),
    asyncHandler(async (req, res) => {
      const { role, rows } = req.body as CheckRowsInput;
      res.json({ success: true, data: { issues: await service.check(tenantOf(req), role, rows) } });
    }),
  );

  router.post(
    '/submit',
    validate({ body: submitRowsSchema }),
    asyncHandler(async (req, res) => {
      const { role, rows, draftId } = req.body as SubmitRowsInput;
      res.json({
        success: true,
        data: await service.submit(tenantOf(req), actorOf(req), role, rows, draftId),
      });
    }),
  );

  router.get(
    '/drafts',
    validate({ query: draftListQuerySchema }),
    asyncHandler(async (req, res) => {
      const { role } = req.query as unknown as DraftListQuery;
      res.json({ success: true, data: { items: await service.listDrafts(tenantOf(req), role) } });
    }),
  );

  router.post(
    '/drafts',
    validate({ body: draftCreateSchema }),
    asyncHandler(async (req, res) => {
      res.status(201).json({
        success: true,
        data: await service.createDraft(tenantOf(req), actorOf(req), req.body),
      });
    }),
  );

  router.get(
    '/drafts/:id',
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.getDraft(tenantOf(req), req.params.id) });
    }),
  );

  router.put(
    '/drafts/:id',
    validate({ body: draftUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.updateDraft(tenantOf(req), req.params.id, req.body),
      });
    }),
  );

  router.delete(
    '/drafts/:id',
    asyncHandler(async (req, res) => {
      await service.deleteDraft(tenantOf(req), req.params.id);
      res.json({ success: true, data: {} });
    }),
  );

  return router;
}
