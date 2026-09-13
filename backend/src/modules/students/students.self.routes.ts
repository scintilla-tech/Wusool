import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createAuthenticate } from '../../middlewares/authenticate';
import { authorize } from '../../middlewares/authorize';
import { MockOtpProvider } from '../../providers/otp';
import { OtpService } from '../otp/otp.service';
import { StudentSelfService } from './students.self.service';
import { profileUpdateSchema, registerSchema, verifySchema } from './students.self.schemas';
import type { ScopeDeps } from '../../middlewares/scope';

export function createStudentsSelfRouter(deps: ScopeDeps): Router {
  const router = Router();
  const otp = new OtpService(new MockOtpProvider());
  const service = new StudentSelfService(deps.prisma, otp, deps.config.NODE_ENV === 'development');
  const authenticate = createAuthenticate({
    prisma: deps.prisma,
    accessSecret: deps.config.JWT_ACCESS_SECRET,
  });

  router.post(
    '/register',
    validate({ body: registerSchema }),
    asyncHandler(async (req, res) => {
      res.status(201).json({ success: true, data: await service.register(req.body) });
    }),
  );

  router.post(
    '/verify',
    validate({ body: verifySchema }),
    asyncHandler(async (req, res) => {
      await service.verify(req.body.userId, req.body.code);
      res.json({ success: true, data: { verified: true } });
    }),
  );

  router.get(
    '/me',
    authenticate,
    authorize('STUDENT'),
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.getMe(req.auth?.userId as string) });
    }),
  );

  router.patch(
    '/me',
    authenticate,
    authorize('STUDENT'),
    validate({ body: profileUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.updateMe(req.auth?.userId as string, req.body),
      });
    }),
  );

  return router;
}
