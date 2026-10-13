import { createServer, type Server as HttpServer } from 'node:http';
import { PrismaClient } from '@prisma/client';
import { config as loadDotenv } from 'dotenv';
import request from 'supertest';
import { io as connect, type Socket as ClientSocket } from 'socket.io-client';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { createApp } from '../../src/app';
import { createLogger } from '../../src/config/logger';
import { LocationService } from '../../src/modules/tracking/location.service';
import { TripEventBus } from '../../src/modules/trips/trip-events';
import { TripService } from '../../src/modules/trips/trips.service';
import { createSocketServer } from '../../src/sockets';
import { todayDate } from '../../src/utils/date';
import { testEnv } from '../helpers';

const run = process.env.RUN_E2E_TESTS === '1';
if (run) loadDotenv({ path: '.env.demo.local', override: false });
if (run) loadDotenv({ path: '.env.attendance-demo.local', override: false });
const suite = run ? describe : describe.skip;
const prisma = new PrismaClient();
const outboundTripId = 'demo-trip-nejood';
const returnTripId = 'demo-trip-return-nejood';

type Login = { accessToken: string; user: { id: string } };

function once<T>(socket: ClientSocket, event: string): Promise<T> {
  return new Promise((resolve) => socket.once(event, resolve));
}

suite('dual attendance local PostgreSQL workflow', () => {
  let httpServer: HttpServer;
  let socketServer: ReturnType<typeof createSocketServer>;
  let origin: string;
  const clients: ClientSocket[] = [];

  beforeAll(async () => {
    const currentBusinessDate = todayDate();
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(
      new Date(
        Date.UTC(
          currentBusinessDate.getUTCFullYear(),
          currentBusinessDate.getUTCMonth(),
          currentBusinessDate.getUTCDate(),
          9,
        ),
      ),
    );
    const config = { ...testEnv, DATABASE_URL: process.env.DATABASE_URL! };
    const events = new TripEventBus();
    const tripService = new TripService(prisma, events);
    const locationService = new LocationService(prisma, tripService);
    const app = createApp({
      config,
      logger: createLogger(config),
      prisma,
      tripService,
      locationService,
      tripEvents: events,
    });
    httpServer = createServer(app);
    socketServer = createSocketServer(httpServer, {
      prisma,
      accessSecret: config.JWT_ACCESS_SECRET,
      locationService,
      allowedOrigins: [],
      tripEvents: events,
    });
    await new Promise<void>((resolve) => httpServer.listen(0, '127.0.0.1', resolve));
    const address = httpServer.address();
    if (!address || typeof address === 'string') throw new Error('Missing test server address');
    origin = `http://127.0.0.1:${address.port}`;

    const today = todayDate();
    await prisma.dailyTrip.updateMany({
      where: { id: { in: [outboundTripId, returnTripId] } },
      data: { tripDate: today, status: 'SCHEDULED', startedAt: null, completedAt: null },
    });
    await prisma.attendanceSession.updateMany({
      where: { dailyTripId: { in: [outboundTripId, returnTripId] } },
      data: { status: 'OPEN', closedAt: null, closedByDriverProfileId: null },
    });
  });

  afterAll(async () => {
    for (const client of clients) client.disconnect();
    await prisma.dailyTrip.updateMany({
      where: { id: { in: [outboundTripId, returnTripId] } },
      data: { status: 'SCHEDULED', startedAt: null, completedAt: null },
    });
    await prisma.attendanceSession.updateMany({
      where: { dailyTripId: { in: [outboundTripId, returnTripId] } },
      data: { status: 'OPEN', closedAt: null, closedByDriverProfileId: null },
    });
    await new Promise<void>((resolve) => socketServer.close(() => resolve()));
    if (httpServer.listening)
      await new Promise<void>((resolve) => httpServer.close(() => resolve()));
    await prisma.$disconnect();
    vi.useRealTimers();
  });

  async function login(phone: string, password: string): Promise<Login> {
    const response = await request(origin)
      .post('/api/v1/auth/login')
      .send({ tenantCode: 'KSU', phone, password });
    expect(response.status).toBe(200);
    return response.body.data as Login;
  }

  it('runs independent outbound and return sessions with assisted attendance and closure', async () => {
    const demoPassword = process.env.ATTENDANCE_DEMO_PASSWORD ?? process.env.DEMO_PASSWORD!;
    const legacyPassword = process.env.LEGACY_DRIVER_PASSWORD!;
    const student = await login('+966500000101', demoPassword);
    const driver = await login('+966500000102', demoPassword);
    const unrelatedDriver = await login('+966550000001', legacyPassword);

    const demoStudent = await prisma.studentProfile.findFirstOrThrow({
      where: { userId: student.user.id },
      select: { id: true },
    });
    const assignedPeer = await prisma.tripStudent.findFirstOrThrow({
      where: { dailyTripId: outboundTripId, studentProfileId: { not: demoStudent.id } },
      select: { studentProfileId: true },
    });
    const unrelatedStudent = await prisma.studentProfile.findFirstOrThrow({
      where: {
        studentAssignments: { some: { route: { code: 'R2' }, isActive: true } },
      },
      select: { id: true },
    });

    const socket = connect(origin, {
      transports: ['websocket'],
      auth: { token: student.accessToken },
      forceNew: true,
    });
    clients.push(socket);
    await once(socket, 'connect');

    const outbound = await request(origin)
      .put('/api/v1/attendance/today/OUTBOUND')
      .set('Authorization', `Bearer ${student.accessToken}`)
      .send({ intent: 'ATTENDING', expectedFinishTime: '15:30' });
    expect(outbound.status).toBe(200);
    expect(outbound.body.data).toMatchObject({
      direction: 'OUTBOUND',
      intent: 'ATTENDING',
      expectedFinishTime: '15:30',
      source: 'STUDENT_SELF_REGISTRATION',
    });
    await expect(
      prisma.attendanceIntent.findFirst({
        where: { studentProfileId: demoStudent.id, direction: 'OUTBOUND' },
        orderBy: { operationalDate: 'desc' },
      }),
    ).resolves.toMatchObject({ intent: 'ATTENDING', expectedFinishMinutes: 930 });

    const assisted = await request(origin)
      .put(`/api/v1/driver/${outboundTripId}/attendance/${assignedPeer.studentProfileId}`)
      .set('Authorization', `Bearer ${driver.accessToken}`)
      .send({ intent: 'ABSENT', note: 'Assisted local E2E' });
    expect(assisted.status).toBe(200);
    expect(assisted.body.data.source).toBe('DRIVER_ASSISTED_REGISTRATION');

    const unrelatedStudentAttempt = await request(origin)
      .put(`/api/v1/driver/${outboundTripId}/attendance/${unrelatedStudent.id}`)
      .set('Authorization', `Bearer ${driver.accessToken}`)
      .send({ intent: 'ATTENDING' });
    expect(unrelatedStudentAttempt.status).toBe(404);

    const unauthorizedClose = await request(origin)
      .post(`/api/v1/driver/${outboundTripId}/attendance/close`)
      .set('Authorization', `Bearer ${unrelatedDriver.accessToken}`)
      .send({ confirm: true });
    expect(unauthorizedClose.status).toBe(404);

    const outboundClosedEvent = once<{ direction: string }>(socket, 'attendance:closed');
    const closeOutbound = await request(origin)
      .post(`/api/v1/driver/${outboundTripId}/attendance/close`)
      .set('Authorization', `Bearer ${driver.accessToken}`)
      .send({ confirm: true });
    expect(closeOutbound.status).toBe(200);
    expect(closeOutbound.body.data.status).toBe('CLOSED');
    await expect(outboundClosedEvent).resolves.toMatchObject({ direction: 'OUTBOUND' });
    await expect(
      prisma.dailyTrip.findUnique({ where: { id: outboundTripId } }),
    ).resolves.toMatchObject({ status: 'SCHEDULED' });

    const afterClose = await request(origin)
      .put('/api/v1/attendance/today/OUTBOUND')
      .set('Authorization', `Bearer ${student.accessToken}`)
      .send({ intent: 'ABSENT' });
    expect(afterClose.status).toBe(409);

    const sessionsAfterOutboundClose = await request(origin)
      .get('/api/v1/attendance/today')
      .set('Authorization', `Bearer ${student.accessToken}`);
    expect(sessionsAfterOutboundClose.status).toBe(200);
    expect(sessionsAfterOutboundClose.body.data.sessions).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ direction: 'OUTBOUND', status: 'CLOSED' }),
        expect.objectContaining({ direction: 'RETURN', status: 'OPEN', isOpen: true }),
      ]),
    );

    const registerReturn = await request(origin)
      .put('/api/v1/attendance/today/RETURN')
      .set('Authorization', `Bearer ${student.accessToken}`)
      .send({ intent: 'ATTENDING' });
    expect(registerReturn.status).toBe(200);
    expect(registerReturn.body.data.expectedFinishTime).toBeNull();

    const [closeReturn, concurrentRegistration] = await Promise.all([
      request(origin)
        .post(`/api/v1/driver/${returnTripId}/attendance/close`)
        .set('Authorization', `Bearer ${driver.accessToken}`)
        .send({ confirm: true }),
      request(origin)
        .put('/api/v1/attendance/today/RETURN')
        .set('Authorization', `Bearer ${student.accessToken}`)
        .send({ intent: 'ABSENT' }),
    ]);
    expect(closeReturn.status).toBe(200);
    expect([200, 409]).toContain(concurrentRegistration.status);
    const returnSession = await prisma.attendanceSession.findUniqueOrThrow({
      where: { dailyTripId: returnTripId },
    });
    expect(returnSession.status).toBe('CLOSED');

    const finalReturnUpdate = await request(origin)
      .put('/api/v1/attendance/today/RETURN')
      .set('Authorization', `Bearer ${student.accessToken}`)
      .send({ intent: 'ATTENDING' });
    expect(finalReturnUpdate.status).toBe(409);

    const audit = await prisma.attendanceAudit.findMany({
      where: { studentProfileId: demoStudent.id },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ source: 'STUDENT_SELF_REGISTRATION', actorRole: 'STUDENT' }),
      ]),
    );
    await expect(
      prisma.attendanceAudit.findFirst({
        where: {
          studentProfileId: assignedPeer.studentProfileId,
          source: 'DRIVER_ASSISTED_REGISTRATION',
        },
        orderBy: { createdAt: 'desc' },
      }),
    ).resolves.toMatchObject({ actorRole: 'DRIVER', attendanceStatus: 'ABSENT' });

    for (const tripId of [outboundTripId, returnTripId]) {
      const start = await request(origin)
        .post(`/api/v1/driver/${tripId}/start`)
        .set('Authorization', `Bearer ${driver.accessToken}`);
      expect(start.status).toBe(200);
      const complete = await request(origin)
        .post(`/api/v1/driver/${tripId}/complete`)
        .set('Authorization', `Bearer ${driver.accessToken}`);
      expect(complete.status).toBe(200);
      await expect(prisma.dailyTrip.findUnique({ where: { id: tripId } })).resolves.toMatchObject({
        status: 'COMPLETED',
      });
    }
  }, 30_000);
});
