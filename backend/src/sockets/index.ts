import type { Server as HttpServer } from 'node:http';
import type { Prisma, PrismaClient, Role } from '@prisma/client';
import { Server, type Socket } from 'socket.io';
import { z } from 'zod';
import { dateOnly } from '../utils/date';
import { verifyAccessToken } from '../utils/token';
import { LocationService } from '../modules/tracking/location.service';
import type { TripEventBus } from '../modules/trips/trip-events';

const MAX_LOCATION_CLOCK_SKEW_MS = 5 * 60 * 1000;
const AUTHORIZATION_REFRESH_MS = 60 * 1000;

const locationSchema = z
  .object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    timestamp: z.number().int().nonnegative(),
  })
  .strict();

export interface SocketDeps {
  prisma: PrismaClient;
  accessSecret: string;
  locationService: LocationService;
  allowedOrigins: string[];
  tripEvents?: TripEventBus;
}

export interface AuthorizedSocketContext {
  userId: string;
  role: Role;
  tenantId: string | null;
  rooms: string[];
}

type LocationAcknowledgement = (result: {
  success: boolean;
  tripId?: string;
  broadcast?: boolean;
  autoCompleted?: boolean;
  error?: { code: string; message: string };
}) => void;

function tripRooms(tenantId: string, trips: Array<{ id: string }>): string[] {
  return trips.map((trip) => `tenant:${tenantId}:trip:${trip.id}`);
}

function staffTripRooms(tenantId: string, trips: Array<{ id: string }>): string[] {
  return trips.map((trip) => `tenant:${tenantId}:trip:${trip.id}:staff`);
}

/** Resolve every room from fresh database relationships; clients never choose room names. */
export async function resolveAuthorizedSocketContext(
  prisma: PrismaClient,
  userId: string,
): Promise<AuthorizedSocketContext | null> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      role: true,
      tenantId: true,
      isActive: true,
      tenant: { select: { isActive: true } },
    },
  });
  if (!user?.isActive || (user.tenantId !== null && user.tenant?.isActive !== true)) return null;

  const rooms = [`user:${user.id}`];
  if (!user.tenantId) {
    return { userId: user.id, role: user.role, tenantId: null, rooms };
  }

  const tenantId = user.tenantId;
  const today = dateOnly(new Date());
  const activeTripWhere = {
    tenantId,
    tripDate: today,
    status: { in: ['IN_PROGRESS', 'SCHEDULED'] },
  } satisfies Prisma.DailyTripWhereInput;

  if (user.role === 'STUDENT') {
    const profile = await prisma.studentProfile.findFirst({
      where: { userId, tenantId, isActive: true },
      select: { id: true },
    });
    if (profile) {
      const trips = await prisma.dailyTrip.findMany({
        where: {
          ...activeTripWhere,
          tripStudents: { some: { studentProfileId: profile.id, tenantId } },
        },
        select: { id: true, busId: true },
      });
      rooms.push(...tripRooms(tenantId, trips));
    }
  } else if (user.role === 'DRIVER') {
    const profile = await prisma.driverProfile.findFirst({
      where: { userId, tenantId, isActive: true },
      select: { id: true },
    });
    if (profile) {
      const trips = await prisma.dailyTrip.findMany({
        where: { ...activeTripWhere, driverProfileId: profile.id },
        select: { id: true, busId: true },
      });
      rooms.push(...tripRooms(tenantId, trips));
      rooms.push(...staffTripRooms(tenantId, trips));
    }
  } else if (user.role === 'SUPERVISOR') {
    const profile = await prisma.supervisorProfile.findFirst({
      where: { userId, tenantId, isActive: true },
      select: { id: true },
    });
    if (profile) {
      const assignments = await prisma.supervisorBusAssignment.findMany({
        where: { tenantId, supervisorProfileId: profile.id, isActive: true },
        select: { busId: true },
      });
      const trips = await prisma.dailyTrip.findMany({
        where: { ...activeTripWhere, busId: { in: assignments.map((a) => a.busId) } },
        select: { id: true, busId: true },
      });
      rooms.push(...tripRooms(tenantId, trips));
      rooms.push(...staffTripRooms(tenantId, trips));
    }
  } else if (user.role === 'FIELD_SUPERVISOR' || user.role === 'UNIVERSITY_ADMIN') {
    const trips = await prisma.dailyTrip.findMany({
      where: activeTripWhere,
      select: { id: true, busId: true },
    });
    rooms.push(...tripRooms(tenantId, trips));
    rooms.push(...staffTripRooms(tenantId, trips));
  }

  return { userId: user.id, role: user.role, tenantId, rooms: [...new Set(rooms)] };
}

function joinAuthorizedRooms(socket: Socket, context: AuthorizedSocketContext): void {
  for (const room of context.rooms) socket.join(room);
}

function replaceAuthorizedRooms(
  socket: Socket,
  previous: AuthorizedSocketContext,
  next: AuthorizedSocketContext,
): void {
  for (const room of previous.rooms) {
    if (!next.rooms.includes(room)) socket.leave(room);
  }
  joinAuthorizedRooms(socket, next);
  socket.data.auth = next;
}

export function createSocketServer(httpServer: HttpServer, deps: SocketDeps): Server {
  const io = new Server(httpServer, {
    cors: {
      credentials: true,
      origin: (origin, callback) => {
        if (!origin) callback(null, true);
        else if (origin === 'null') callback(new Error('ORIGIN_NOT_ALLOWED'));
        else callback(null, deps.allowedOrigins.includes(origin));
      },
    },
  });

  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.token;
    if (typeof token !== 'string' || token.length === 0) {
      next(new Error('UNAUTHORIZED'));
      return;
    }
    try {
      const payload = verifyAccessToken(token, deps.accessSecret);
      const context = await resolveAuthorizedSocketContext(deps.prisma, payload.sub);
      if (!context) {
        next(new Error('UNAUTHORIZED'));
        return;
      }
      socket.data.auth = context;
      socket.data.tokenExpiresAt = payload.exp ? payload.exp * 1000 : Date.now();
      next();
    } catch {
      next(new Error('UNAUTHORIZED'));
    }
  });

  io.on('connection', (socket) => {
    let context = socket.data.auth as AuthorizedSocketContext;
    joinAuthorizedRooms(socket, context);

    const refreshAuthorization = async (): Promise<AuthorizedSocketContext | null> => {
      if (Date.now() >= (socket.data.tokenExpiresAt as number)) {
        socket.disconnect(true);
        return null;
      }
      const refreshed = await resolveAuthorizedSocketContext(deps.prisma, context.userId);
      if (!refreshed) {
        socket.disconnect(true);
        return null;
      }
      replaceAuthorizedRooms(socket, context, refreshed);
      context = refreshed;
      return refreshed;
    };

    const authorizationTimer = setInterval(() => {
      void refreshAuthorization().catch(() => socket.disconnect(true));
    }, AUTHORIZATION_REFRESH_MS);
    authorizationTimer.unref();
    const expiryDelay = Math.max(0, (socket.data.tokenExpiresAt as number) - Date.now());
    const expiryTimer = setTimeout(() => socket.disconnect(true), expiryDelay);
    expiryTimer.unref();
    socket.once('disconnect', () => {
      clearInterval(authorizationTimer);
      clearTimeout(expiryTimer);
    });

    socket.on('trip:location', async (payload: unknown, acknowledge?: LocationAcknowledgement) => {
      const ack = typeof acknowledge === 'function' ? acknowledge : undefined;
      const rejectLocation = (code: string, message: string): void => {
        const error = { code, message };
        socket.emit('trip:error', error);
        ack?.({ success: false, error });
      };

      if (socket.data.locationInFlight === true) {
        rejectLocation('RATE_LIMITED', 'A location update is already being processed');
        return;
      }
      const lastLocationAt = (socket.data.lastLocationAt as number | undefined) ?? 0;
      if (Date.now() - lastLocationAt < 1_000) {
        rejectLocation('RATE_LIMITED', 'Location updates are too frequent');
        return;
      }
      socket.data.locationInFlight = true;
      socket.data.lastLocationAt = Date.now();
      try {
        const current = await refreshAuthorization();
        if (!current || current.role !== 'DRIVER' || !current.tenantId) {
          rejectLocation('FORBIDDEN', 'Location publishing denied');
          return;
        }
        const parsed = locationSchema.parse(payload);
        if (Math.abs(Date.now() - parsed.timestamp) > MAX_LOCATION_CLOCK_SKEW_MS) {
          rejectLocation('STALE_LOCATION', 'Location timestamp is stale');
          return;
        }

        const result = await deps.locationService.processLocation(
          current.tenantId,
          current.userId,
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
          const rooms = [`tenant:${current.tenantId}:trip:${result.tripId}`];
          io.to(rooms).emit('trip:location', location);
        }

        if (result.autoCompleted) {
          io.to(`tenant:${current.tenantId}:trip:${result.tripId}`).emit('trip:arrived', {
            tripId: result.tripId,
          });
        }
        ack?.({
          success: true,
          tripId: result.tripId,
          broadcast: result.broadcast,
          autoCompleted: result.autoCompleted,
        });
      } catch {
        rejectLocation('INVALID_LOCATION', 'Invalid location update');
      } finally {
        socket.data.locationInFlight = false;
      }
    });
  });

  const unsubscribeTripCompleted = deps.tripEvents?.onCompleted(({ tenantId, tripId }) => {
    const room = `tenant:${tenantId}:trip:${tripId}`;
    io.to(room).emit('trip:completed', { tripId });
    io.in(room).socketsLeave(room);
  });
  const unsubscribeAttendanceChanged = deps.tripEvents?.onAttendanceChanged((event) => {
    if (!event.tripId) return;
    const staffPayload = {
      tripId: event.tripId,
      attendanceSessionId: event.attendanceSessionId,
      direction: event.direction,
      studentProfileId: event.studentProfileId,
      intent: event.intent,
    };
    io.to(`tenant:${event.tenantId}:trip:${event.tripId}:staff`).emit(
      'attendance:changed',
      staffPayload,
    );
    io.to(`user:${event.studentUserId}`).emit('attendance:changed', {
      tripId: event.tripId,
      attendanceSessionId: event.attendanceSessionId,
      direction: event.direction,
      intent: event.intent,
    });
  });
  const unsubscribeAttendanceClosed = deps.tripEvents?.onAttendanceClosed((event) => {
    io.to(`tenant:${event.tenantId}:trip:${event.tripId}`).emit('attendance:closed', {
      tripId: event.tripId,
      attendanceSessionId: event.attendanceSessionId,
      direction: event.direction,
      closedAt: event.closedAt,
    });
  });
  if (unsubscribeTripCompleted) io.once('close', unsubscribeTripCompleted);
  if (unsubscribeAttendanceChanged) io.once('close', unsubscribeAttendanceChanged);
  if (unsubscribeAttendanceClosed) io.once('close', unsubscribeAttendanceClosed);

  return io;
}
