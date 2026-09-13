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
import { createAssignmentsRouter } from './modules/assignments/assignments.routes';

export interface AppDeps {
  config: EnvConfig;
  logger: Logger;
  prisma: PrismaClient;
}

export function createApp({ config, logger, prisma }: AppDeps): Express {
  const app = express();

  app.disable('x-powered-by');

  if (config.TRUST_PROXY > 0) {
    app.set('trust proxy', config.TRUST_PROXY);
  }

  app.use(createRequestLogger(logger, config));
  app.use(helmet());

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

  app.use('/api/v1/auth', createAuthRouter({ prisma, config }));
  app.use('/api/v1/structure', createStructureRouter(scopeDeps));
  app.use('/api/v1/employees', createEmployeesRouter(scopeDeps));
  app.use('/api/v1/students', createStudentsRouter(scopeDeps));
  app.use('/api/v1/assignments', createAssignmentsRouter(scopeDeps));

  app.use(notFoundHandler);
  app.use(errorHandler(logger, config.NODE_ENV === 'production'));

  return app;
}
