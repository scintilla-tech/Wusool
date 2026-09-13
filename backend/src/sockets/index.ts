import type { Server as HttpServer } from 'node:http';
import type { PrismaClient } from '@prisma/client';
import { Server } from 'socket.io';
import { z } from 'zod';
import { verifyAccessToken } from '../utils/token';
import { LocationService } from '../modules/tracking/location.service';

const locationSchema = z
  .object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
  })
  .strict();

export interface SocketDeps {
  prisma: PrismaClient;
  accessSecret: string;
  locationService: LocationService;
}

/**
 * Socket.IO bootstrap. The server controls room membership; clients never join
 * arbitrary rooms. Every sensitive event re-validates authorization server-side.
 */
export function createSocketServer(httpServer: HttpServer, deps: SocketDeps): Server {
  const io = new Server(httpServer, { cors: { origin: false } });

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) {
      next(new Error('UNAUTHORIZED'));
      return;
    }
    try {
      const payload = verifyAccessToken(token, deps.accessSecret);
      socket.data.userId = payload.sub;
      next();
    } catch {
      next(new Error('UNAUTHORIZED'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.data.userId as string;

    socket.on('trip:location', async (payload: unknown) => {
      try {
        const parsed = locationSchema.parse(payload);
        const user = await deps.prisma.user.findUnique({ where: { id: userId } });
        if (!user || user.role !== 'DRIVER' || !user.isActive || !user.tenantId) return;
        const tenantId = user.tenantId;

        const result = await deps.locationService.processLocation(
          tenantId,
          userId,
          parsed.latitude,
          parsed.longitude,
        );

        if (result.broadcast) {
          const location = {
            tripId: result.tripId,
            latitude: result.latitude,
            longitude: result.longitude,
            at: Date.now(),
          };
          io.to(`tenant:${tenantId}:trip:${result.tripId}`).emit('trip:location', location);
          if (result.busId) {
            io.to(`tenant:${tenantId}:bus:${result.busId}`).emit('trip:location', location);
          }
        }

        if (result.autoCompleted) {
          io.to(`tenant:${tenantId}:trip:${result.tripId}`).emit('trip:arrived', {
            tripId: result.tripId,
          });
          io.to(`tenant:${tenantId}:trip:${result.tripId}`).emit('trip:completed', {
            tripId: result.tripId,
          });
        }
      } catch {
        socket.emit('trip:error', { message: 'Invalid location update' });
      }
    });

    socket.on('disconnect', () => {
      // Socket.IO auto-leaves rooms on disconnect.
    });
  });

  return io;
}
