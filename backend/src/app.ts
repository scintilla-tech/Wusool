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

export interface AppDeps {
  config: EnvConfig;
  logger: Logger;
  prisma: PrismaClient;
}

export function createApp({ config, logger, prisma }: AppDeps): Express {
  const app = express();

  app.disable('x-powered-by');

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

  app.use(notFoundHandler);
  app.use(errorHandler(logger, config.NODE_ENV === 'production'));

  return app;
}
