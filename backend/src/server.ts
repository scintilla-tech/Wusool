import 'dotenv/config';
import { createServer, type Server } from 'node:http';
import { loadEnvConfig } from './config/env';
import { createLogger, scrub } from './config/logger';
import { getPrismaClient, disconnectPrisma } from './providers/prisma';
import { createApp } from './app';
import { createSocketServer } from './sockets';
import { LocationService } from './modules/tracking/location.service';
import { TripService } from './modules/trips/trips.service';

const SHUTDOWN_TIMEOUT_MS = 10_000;

async function main(): Promise<void> {
  const config = loadEnvConfig(process.env);
  const logger = createLogger(config);
  const prisma = getPrismaClient();
  const app = createApp({ config, logger, prisma });

  const httpServer: Server = createServer(app);

  const tripService = new TripService(prisma);
  const locationService = new LocationService(prisma, tripService);
  const io = createSocketServer(httpServer, {
    prisma,
    accessSecret: config.JWT_ACCESS_SECRET,
    locationService,
  });

  httpServer.listen(config.PORT, () => {
    logger.info({ port: config.PORT, env: config.NODE_ENV }, 'WASL API started');
  });

  const shutdown = (signal: string): void => {
    logger.info({ signal }, 'Shutting down');

    const forceExit = setTimeout(() => {
      logger.error('Forced shutdown after timeout');
      process.exit(1);
    }, SHUTDOWN_TIMEOUT_MS);
    forceExit.unref();

    io.close(() => {
      httpServer.close(() => {
        void disconnectPrisma().then(() => {
          clearTimeout(forceExit);
          process.exit(0);
        });
      });
    });
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

main().catch((err) => {
  const message = err instanceof Error ? scrub(err.message) : String(err);
  console.error('Failed to start server:', message);
  process.exit(1);
});
