import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createAuthenticate } from '../../middlewares/authenticate';
import { authorize } from '../../middlewares/authorize';
import { requireTenant } from '../../middlewares/requireTenant';
import { createRateLimiter } from '../../middlewares/rateLimit';
import { MockOtpProvider } from '../../providers/otp';
import { OtpService } from '../otp/otp.service';
import { StudentSelfService } from './students.self.service';
import { StudentTripService } from '../trips/student-trip.service';
import { profileUpdateSchema, registerSchema, verifySchema } from './students.self.schemas';
import type { ScopeDeps } from '../../middlewares/scope';
import type { LocationService } from '../tracking/location.service';

export interface StudentsSelfDeps extends ScopeDeps {
  locationService: LocationService;
}

export function createStudentsSelfRouter(deps: StudentsSelfDeps): Router {
  const router = Router();
  const otp = new OtpService(new MockOtpProvider());
  const service = new StudentSelfService(deps.prisma, otp, deps.config.NODE_ENV === 'development');
  const tripService = new StudentTripService(deps.prisma, deps.locationService);
  const authenticate = createAuthenticate({
    prisma: deps.prisma,
    accessSecret: deps.config.JWT_ACCESS_SECRET,
  });
  const registerLimiter = createRateLimiter({ windowMs: 15 * 60 * 1000, limit: 5 });
  const verifyLimiter = createRateLimiter({ windowMs: 15 * 60 * 1000, limit: 10 });

  if (deps.config.PUBLIC_STUDENT_REGISTRATION) {
    router.post(
      '/register',
      registerLimiter,
      validate({ body: registerSchema }),
      asyncHandler(async (req, res) => {
        res.status(201).json({ success: true, data: await service.register(req.body) });
      }),
    );

    router.post(
      '/verify',
      verifyLimiter,
      validate({ body: verifySchema }),
      asyncHandler(async (req, res) => {
        await service.verify(req.body.userId, req.body.code);
        res.json({ success: true, data: { verified: true } });
      }),
    );
  }

  router.get(
    '/me',
    authenticate,
    authorize('STUDENT'),
    requireTenant,
    asyncHandler(async (req, res) => {
      res.json({ success: true, data: await service.getMe(req.auth?.userId as string) });
    }),
  );

  router.patch(
    '/me',
    authenticate,
    authorize('STUDENT'),
    requireTenant,
    validate({ body: profileUpdateSchema }),
    asyncHandler(async (req, res) => {
      res.json({
        success: true,
        data: await service.updateMe(req.auth?.userId as string, req.body),
      });
    }),
  );

  router.get(
    '/me/trip',
    authenticate,
    authorize('STUDENT'),
    requireTenant,
    asyncHandler(async (req, res) => {
      const tenantId = req.auth?.tenantId as string;
      res.json({
        success: true,
        data: await tripService.getTodayTrip(tenantId, req.auth?.userId as string),
      });
    }),
  );

  return router;
}
