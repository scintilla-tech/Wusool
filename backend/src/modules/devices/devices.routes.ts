import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler';
import { validate } from '../../middlewares/validate';
import { createAuthenticate } from '../../middlewares/authenticate';
import { deactivateDeviceSchema, registerDeviceSchema } from './devices.schemas';
import type { ScopeDeps } from '../../middlewares/scope';

export function createDevicesRouter(deps: ScopeDeps): Router {
  const router = Router();
  const authenticate = createAuthenticate({
    prisma: deps.prisma,
    accessSecret: deps.config.JWT_ACCESS_SECRET,
  });

  router.post(
    '/',
    authenticate,
    validate({ body: registerDeviceSchema }),
    asyncHandler(async (req, res) => {
      const userId = req.auth?.userId as string;
      const tenantId = req.auth?.tenantId ?? null;
      const { token, platform, deviceId } = req.body;

      const device = await deps.prisma.deviceToken.upsert({
        // A provider token represents one physical app installation and must
        // belong to only one current account. Re-registration transfers it.
        where: { token },
        update: { userId, platform, deviceId: deviceId ?? null, isActive: true, tenantId },
        create: { userId, tenantId, token, platform, deviceId: deviceId ?? null },
      });

      res.status(201).json({ success: true, data: { id: device.id } });
    }),
  );

  router.delete(
    '/',
    authenticate,
    validate({ body: deactivateDeviceSchema }),
    asyncHandler(async (req, res) => {
      const userId = req.auth?.userId as string;
      const { deviceId } = req.body;
      const result = await deps.prisma.deviceToken.updateMany({
        where: {
          userId,
          isActive: true,
          OR: [{ deviceId }, { deviceId: null }],
        },
        data: { isActive: false },
      });
      res.json({ success: true, data: { deactivated: result.count } });
    }),
  );

  return router;
}
