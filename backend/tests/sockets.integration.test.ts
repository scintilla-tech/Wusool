import { createServer } from 'node:http';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { io as connect, type Socket as ClientSocket } from 'socket.io-client';
import type { PrismaClient } from '@prisma/client';
import { createSocketServer } from '../src/sockets';
import { signAccessToken } from '../src/utils/token';
import { testEnv } from './helpers';

const clients: ClientSocket[] = [];

afterEach(() => {
  for (const client of clients.splice(0)) client.disconnect();
});

function once<T>(socket: ClientSocket, event: string): Promise<T> {
  return new Promise((resolve) => socket.once(event, resolve));
}

describe('Socket.IO authorization boundary', () => {
  it('rejects unauthenticated clients and isolates location to explicit trip members', async () => {
    const users = new Map([
      ['driver-user', { role: 'DRIVER', profile: 'driver-1' }],
      ['student-user', { role: 'STUDENT', profile: 'student-1' }],
      ['outsider-user', { role: 'STUDENT', profile: 'student-2' }],
    ]);
    const prisma = {
      user: {
        findUnique: vi.fn(async ({ where }: { where: { id: string } }) => {
          const user = users.get(where.id);
          return user
            ? {
                id: where.id,
                role: user.role,
                tenantId: 'tenant-1',
                isActive: true,
                tenant: { isActive: true },
              }
            : null;
        }),
      },
      driverProfile: {
        findFirst: vi.fn(async ({ where }: { where: { userId: string } }) => ({
          id: users.get(where.userId)?.profile,
        })),
      },
      studentProfile: {
        findFirst: vi.fn(async ({ where }: { where: { userId: string } }) => ({
          id: users.get(where.userId)?.profile,
        })),
      },
      dailyTrip: {
        findMany: vi.fn(async ({ where }: { where: Record<string, unknown> }) => {
          const membership = where.tripStudents as
            { some?: { studentProfileId?: string } } | undefined;
          if (membership?.some?.studentProfileId === 'student-2') return [];
          return [{ id: 'trip-1', busId: 'bus-1' }];
        }),
      },
    } as unknown as PrismaClient;
    const locationService = {
      processLocation: vi.fn().mockResolvedValue({
        broadcast: true,
        autoCompleted: false,
        tripId: 'trip-1',
        busId: 'bus-1',
        latitude: 24.7,
        longitude: 46.7,
      }),
    };

    const httpServer = createServer();
    const io = createSocketServer(httpServer, {
      prisma,
      accessSecret: testEnv.JWT_ACCESS_SECRET,
      locationService: locationService as never,
      allowedOrigins: [],
    });
    await new Promise<void>((resolve) => httpServer.listen(0, '127.0.0.1', resolve));
    const address = httpServer.address();
    if (!address || typeof address === 'string') throw new Error('Missing test server address');
    const url = `http://127.0.0.1:${address.port}`;

    try {
      const unauthenticated = connect(url, { autoConnect: false, transports: ['websocket'] });
      clients.push(unauthenticated);
      const rejected = once<Error>(unauthenticated, 'connect_error');
      unauthenticated.connect();
      await expect(rejected).resolves.toMatchObject({ message: 'UNAUTHORIZED' });

      const open = async (userId: string) => {
        const token = signAccessToken(
          { sub: userId, type: 'access' },
          testEnv.JWT_ACCESS_SECRET,
          '15m',
        );
        const client = connect(url, {
          autoConnect: false,
          transports: ['websocket'],
          auth: { token },
        });
        clients.push(client);
        const connected = once(client, 'connect');
        client.connect();
        await connected;
        return client;
      };

      const driver = await open('driver-user');
      const student = await open('student-user');
      const outsider = await open('outsider-user');

      const studentLocation = once<Record<string, unknown>>(student, 'trip:location');
      let outsiderReceived = false;
      outsider.on('trip:location', () => {
        outsiderReceived = true;
      });
      driver.emit('trip:location', {
        latitude: 24.7,
        longitude: 46.7,
        timestamp: Date.now(),
      });

      await expect(studentLocation).resolves.toMatchObject({ tripId: 'trip-1' });
      await new Promise((resolve) => setTimeout(resolve, 100));
      expect(outsiderReceived).toBe(false);

      const forbidden = once<Record<string, unknown>>(student, 'trip:error');
      student.emit('trip:location', {
        latitude: 24.7,
        longitude: 46.7,
        timestamp: Date.now(),
      });
      await expect(forbidden).resolves.toMatchObject({ code: 'FORBIDDEN' });

      const malformedAck = once<Record<string, unknown>>(outsider, 'trip:error');
      outsider.emit('trip:location', { latitude: 24.7, longitude: 46.7, timestamp: Date.now() }, {
        not: 'a callback',
      } as never);
      await expect(malformedAck).resolves.toMatchObject({ code: 'FORBIDDEN' });
      expect(outsider.connected).toBe(true);
    } finally {
      await new Promise<void>((resolve) => io.close(() => resolve()));
      if (httpServer.listening)
        await new Promise<void>((resolve) => httpServer.close(() => resolve()));
    }
  });
});
