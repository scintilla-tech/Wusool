import { Router } from 'express';
import type { PrismaClient } from '@prisma/client';
import type { Logger } from 'pino';

export interface HealthDeps {
  prisma: PrismaClient;
  logger: Logger;
}

export function createHealthRouter({ prisma, logger }: HealthDeps): Router {
  const router = Router();

  router.get('/live', (_req, res) => {
    res.status(200).json({ status: 'ok' });
  });

  router.get('/ready', async (_req, res) => {
    try {
      await prisma.$queryRaw`SELECT 1`;
      res.status(200).json({ status: 'ok', database: 'up' });
    } catch (err) {
      logger.error({ err }, 'Database readiness check failed');
      res.status(503).json({ status: 'unavailable', database: 'down' });
    }
  });

  return router;
}
