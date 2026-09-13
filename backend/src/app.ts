import express, { type Express } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import type { PrismaClient } from '@prisma/client';
import type { Logger } from 'pino';
import type { EnvConfig } from './config/env';
import { parseCorsOrigins } from './config/env';
import { createRequestLogger } from './middlewares/requestLogger';
import { notFoundHandler, errorHandler } from './middlewares/errorHandler';
import { createHealthRouter } from './modules/health/health.routes';
import { createAuthRouter } from './modules/auth/auth.routes';
import { createStructureRouter } from './modules/structure/structure.routes';
import { createEmployeesRouter } from './modules/employees/employees.routes';
import { createStudentsRouter } from './modules/students/students.routes';
import { createStudentsSelfRouter } from './modules/students/students.self.routes';
import { createAssignmentsRouter } from './modules/assignments/assignments.routes';
import { createAttendanceRouter } from './modules/attendance/attendance.routes';
import { createTripsRouter } from './modules/trips/trips.routes';
import { createDriverRouter } from './modules/trips/driver.routes';
import { createDevicesRouter } from './modules/devices/devices.routes';
import { createNotificationsRouter } from './modules/notifications/notifications.routes';
import { createSupervisorRouter } from './modules/supervisor/supervisor.routes';
import { createAdminRouter } from './modules/admin/admin.routes';
import { createPlatformRouter } from './modules/platform/platform.routes';
import { createDocumentsRouter } from './modules/documents/documents.routes';
import { LocationService } from './modules/tracking/location.service';
import { TripService } from './modules/trips/trips.service';
import { LocalStorageProvider, type StorageProvider } from './providers/storage';
import { join } from 'node:path';

export interface AppDeps {
  config: EnvConfig;
  logger: Logger;
  prisma: PrismaClient;
  locationService?: LocationService;
  storage?: StorageProvider;
}

export function createApp({
  config,
  logger,
  prisma,
  locationService: injectedLocation,
  storage: injectedStorage,
}: AppDeps): Express {
  const app = express();

  app.disable('x-powered-by');
  // Authenticated API JSON must not be cached. Disabling ETag prevents browsers
  // from sending If-None-Match and receiving a bodyless 304 for endpoints such
  // as /auth/me (which is unusable for API clients).
  app.set('etag', false);

  if (config.TRUST_PROXY > 0) {
    app.set('trust proxy', config.TRUST_PROXY);
  }

  app.use(createRequestLogger(logger, config));
  app.use(helmet());
  app.use((_req, res, next) => {
    res.setHeader('Cache-Control', 'no-store');
    next();
  });

  const allowedOrigins = parseCorsOrigins(config.CORS_ALLOWED_ORIGINS);
  app.use(
    cors({
      origin: (origin, callback) => {
        if (!origin) {
          callback(null, true);
        } else if (origin === 'null') {
          callback(null, false);
        } else {
          callback(null, allowedOrigins.includes(origin));
        }
      },
      credentials: true,
    }),
  );

  app.use(express.json({ limit: '100kb' }));
  app.use(express.urlencoded({ extended: false, limit: '100kb' }));

  app.use('/health', createHealthRouter({ prisma, logger }));

  const scopeDeps = { prisma, config };
  const locationService = injectedLocation ?? new LocationService(prisma, new TripService(prisma));
  const storage =
    injectedStorage ?? new LocalStorageProvider(join(process.cwd(), '.tmp', 'storage'));

  app.use('/api/v1/auth', createAuthRouter({ prisma, config }));
  app.use('/api/v1/structure', createStructureRouter(scopeDeps));
  app.use('/api/v1/employees', createEmployeesRouter(scopeDeps));
  app.use('/api/v1/students', createStudentsSelfRouter({ ...scopeDeps, locationService }));
  app.use('/api/v1/students', createStudentsRouter(scopeDeps));
  app.use('/api/v1/assignments', createAssignmentsRouter(scopeDeps));
  app.use('/api/v1/attendance', createAttendanceRouter(scopeDeps));
  app.use('/api/v1/trips', createTripsRouter(scopeDeps));
  app.use('/api/v1/driver', createDriverRouter(scopeDeps));
  app.use('/api/v1/supervisor', createSupervisorRouter(scopeDeps));
  app.use('/api/v1/admin', createAdminRouter(scopeDeps));
  app.use('/api/v1/platform', createPlatformRouter(scopeDeps));
  app.use('/api/v1/devices', createDevicesRouter(scopeDeps));
  app.use('/api/v1/notifications', createNotificationsRouter(scopeDeps));
  app.use('/api/v1/documents', createDocumentsRouter({ ...scopeDeps, storage }));

  app.use(notFoundHandler);
  app.use(errorHandler(logger, config.NODE_ENV === 'production'));

  return app;
}
