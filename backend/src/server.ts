import 'dotenv/config';
import { createServer, type Server } from 'node:http';
import { loadEnvConfig, parseCorsOrigins } from './config/env';
import { createLogger, scrub } from './config/logger';
import { getPrismaClient, disconnectPrisma } from './providers/prisma';
import { createApp } from './app';
import { createSocketServer } from './sockets';
import { LocationService } from './modules/tracking/location.service';
import { TripService } from './modules/trips/trips.service';
import { TripEventBus } from './modules/trips/trip-events';
import { TripScheduleService } from './modules/trips/trip-schedule.service';
import { createNotificationService } from './modules/notifications/notification.service';

const SHUTDOWN_TIMEOUT_MS = 10_000;

async function main(): Promise<void> {
  const config = loadEnvConfig(process.env);
  if (config.NODE_ENV === 'production' || config.NODE_ENV === 'staging') {
    throw new Error(
      'Production/staging startup refused: real OTP, push, and private durable storage providers are not configured',
    );
  }
  const logger = createLogger(config);
  const prisma = getPrismaClient();

  const tripEvents = new TripEventBus();
  const tripService = new TripService(prisma, tripEvents);
  const locationService = new LocationService(prisma, tripService);

  const app = createApp({ config, logger, prisma, locationService, tripService, tripEvents });
  const httpServer: Server = createServer(app);

  const io = createSocketServer(httpServer, {
    prisma,
    accessSecret: config.JWT_ACCESS_SECRET,
    locationService,
    allowedOrigins: parseCorsOrigins(config.CORS_ALLOWED_ORIGINS),
    tripEvents,
  });

  httpServer.listen(config.PORT, () => {
    logger.info({ port: config.PORT, env: config.NODE_ENV }, 'WASL API started');
  });

  // Each school day at 5:30 am Riyadh time: trips for buses with a fixed route.
  const stopSchedule = new TripScheduleService(
    prisma,
    tripService,
    createNotificationService(prisma),
    logger,
  ).start();

  const shutdown = (signal: string): void => {
    logger.info({ signal }, 'Shutting down');
    stopSchedule();

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
