import { createServer, type Server as HttpServer } from 'node:http';
import { PrismaClient } from '@prisma/client';
import { config as loadDotenv } from 'dotenv';
import request from 'supertest';
import { io as connect, type Socket as ClientSocket } from 'socket.io-client';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
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
const demoTripId = 'demo-trip-nejood';

type Login = { accessToken: string; refreshToken: string; user: { id: string; role: string } };

function once<T>(socket: ClientSocket, event: string): Promise<T> {
  return new Promise((resolve) => socket.once(event, resolve));
}

suite('local database-backed WUSOOL journey', () => {
  let httpServer: HttpServer;
  let socketServer: ReturnType<typeof createSocketServer>;
  let origin: string;
  const clients: ClientSocket[] = [];

  beforeAll(async () => {
    const config = {
      ...testEnv,
      DATABASE_URL: process.env.DATABASE_URL!,
      ATTENDANCE_CUTOFF: '23:59',
    };
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
    if (!address || typeof address === 'string') throw new Error('Missing local server address');
    origin = `http://127.0.0.1:${address.port}`;

    const today = todayDate();

    await prisma.$transaction([
      prisma.dailyTrip.update({
        where: { id: demoTripId },
        data: { tripDate: today, status: 'SCHEDULED', startedAt: null, completedAt: null },
      }),
      prisma.tripStudent.updateMany({
        where: { dailyTripId: demoTripId },
        data: { status: 'WAITING', boardedAt: null, missedAt: null, transportConfirmed: false },
      }),
    ]);
  });

  afterAll(async () => {
    for (const client of clients) client.disconnect();
    await new Promise<void>((resolve) => socketServer.close(() => resolve()));
    if (httpServer.listening) {
      await new Promise<void>((resolve) => httpServer.close(() => resolve()));
    }
    await prisma.$disconnect();
  });

  const login = async (
    phone: string,
    password = process.env.ATTENDANCE_DEMO_PASSWORD ?? process.env.DEMO_PASSWORD,
  ): Promise<Login> => {
    if (!password) throw new Error('DEMO_PASSWORD is required for local E2E');
    const response = await request(origin)
      .post('/api/v1/auth/login')
      .send({ tenantCode: 'KSU', phone, password });
    expect(response.status).toBe(200);
    return response.body.data as Login;
  };

  const openSocket = async (token: string): Promise<ClientSocket> => {
    const socket = connect(origin, {
      autoConnect: false,
      transports: ['websocket'],
      auth: { token },
    });
    clients.push(socket);
    const connected = once(socket, 'connect');
    socket.connect();
    await connected;
    return socket;
  };

  it('persists attendance, trip start, GPS delivery, pickup, supervision, and completion', async () => {
    const student = await login('+966500000101');
    const outsider = await login('+966551000002', process.env.LEGACY_STUDENT_PASSWORD);
    const driver = await login('+966500000102');
    const otherDriver = await login('+966550000001', process.env.LEGACY_DRIVER_PASSWORD);
    const supervisor = await login('+966500000103');
    const admin = await login('+966500000105');

    const pushToken = 'local-e2e-push-token-0001';
    const registeredDevice = await request(origin)
      .post('/api/v1/devices')
      .set('Authorization', `Bearer ${student.accessToken}`)
      .send({ token: pushToken, platform: 'WEB', deviceId: 'local-e2e-browser' });
    expect(registeredDevice.status).toBe(201);
    await expect(
      prisma.deviceToken.findUnique({ where: { token: pushToken } }),
    ).resolves.toMatchObject({ userId: student.user.id, isActive: true });

    const deactivatedDevices = await request(origin)
      .delete('/api/v1/devices')
      .set('Authorization', `Bearer ${student.accessToken}`)
      .send({ deviceId: 'local-e2e-browser' });
    expect(deactivatedDevices.status).toBe(200);
    expect(deactivatedDevices.body.data.deactivated).toBeGreaterThanOrEqual(1);
    await expect(
      prisma.deviceToken.findUnique({ where: { token: pushToken } }),
    ).resolves.toMatchObject({ userId: student.user.id, isActive: false });

    const assigned = await request(origin)
      .get('/api/v1/students/me/trip')
      .set('Authorization', `Bearer ${student.accessToken}`);
    expect(assigned.status).toBe(200);
    expect(assigned.body.data.trip).toMatchObject({ id: demoTripId, status: 'SCHEDULED' });

    const driverToday = await request(origin)
      .get('/api/v1/driver/today')
      .set('Authorization', `Bearer ${driver.accessToken}`);
    expect(driverToday.status).toBe(200);
    expect(driverToday.body.data.id).toBe(demoTripId);
    const demoStudent = driverToday.body.data.tripStudents.find(
      (entry: { studentProfile: { userId: string } }) =>
        entry.studentProfile.userId === 'demo-user-student-nejood',
    );
    expect(demoStudent).toBeTruthy();

    const forbiddenDriver = await request(origin)
      .post(`/api/v1/driver/${demoTripId}/start`)
      .set('Authorization', `Bearer ${otherDriver.accessToken}`);
    expect(forbiddenDriver.status).toBe(404);

    const studentSocket = await openSocket(student.accessToken);
    const outsiderSocket = await openSocket(outsider.accessToken);
    const driverSocket = await openSocket(driver.accessToken);

    const started = await request(origin)
      .post(`/api/v1/driver/${demoTripId}/start`)
      .set('Authorization', `Bearer ${driver.accessToken}`);
    expect(started.status).toBe(200);
    await expect(prisma.dailyTrip.findUnique({ where: { id: demoTripId } })).resolves.toMatchObject(
      {
        status: 'IN_PROGRESS',
      },
    );

    let outsiderReceived = false;
    outsiderSocket.on('trip:location', () => {
      outsiderReceived = true;
    });
    const receivedLocation = once<{ tripId: string; latitude: number }>(
      studentSocket,
      'trip:location',
    );
    driverSocket.emit('trip:location', {
      latitude: 24.75,
      longitude: 46.6,
      timestamp: Date.now(),
    });
    await expect(receivedLocation).resolves.toMatchObject({
      tripId: demoTripId,
      latitude: 24.75,
    });
    await new Promise((resolve) => setTimeout(resolve, 100));
    expect(outsiderReceived).toBe(false);

    const attendance = await request(origin)
      .put('/api/v1/attendance/today')
      .set('Authorization', `Bearer ${student.accessToken}`)
      .send({ intent: 'ATTENDING', note: 'Local E2E verification' });
    expect(attendance.status).toBe(200);
    await expect(
      prisma.attendanceIntent.findFirst({
        where: { studentProfile: { userId: student.user.id }, direction: 'OUTBOUND' },
        orderBy: { operationalDate: 'desc' },
      }),
    ).resolves.toMatchObject({ intent: 'ATTENDING', note: 'Local E2E verification' });

    const boarded = await request(origin)
      .patch(`/api/v1/driver/${demoTripId}/students/${demoStudent.studentProfile.id}`)
      .set('Authorization', `Bearer ${driver.accessToken}`)
      .send({ status: 'BOARDED' });
    expect(boarded.status).toBe(200);
    expect(boarded.body.data.status).toBe('BOARDED');

    const monitored = await request(origin)
      .get('/api/v1/supervisor/buses')
      .set('Authorization', `Bearer ${supervisor.accessToken}`);
    expect(monitored.status).toBe(200);
    expect(monitored.body.data).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          bus: expect.objectContaining({ plateNumber: 'KSU-1003' }),
          trip: expect.objectContaining({ id: demoTripId, status: 'IN_PROGRESS' }),
        }),
      ]),
    );

    const dashboard = await request(origin)
      .get('/api/v1/admin/dashboard')
      .set('Authorization', `Bearer ${admin.accessToken}`);
    expect(dashboard.status).toBe(200);
    expect(dashboard.body.data.tripsByStatus).toEqual(
      expect.arrayContaining([expect.objectContaining({ status: 'IN_PROGRESS', count: 1 })]),
    );

    const studentForbidden = await request(origin)
      .get('/api/v1/admin/dashboard')
      .set('Authorization', `Bearer ${student.accessToken}`);
    expect(studentForbidden.status).toBe(403);

    const completedEvent = once<{ tripId: string }>(studentSocket, 'trip:completed');
    const completed = await request(origin)
      .post(`/api/v1/driver/${demoTripId}/complete`)
      .set('Authorization', `Bearer ${driver.accessToken}`);
    expect(completed.status).toBe(200);
    await expect(completedEvent).resolves.toEqual({ tripId: demoTripId });

    await expect(prisma.dailyTrip.findUnique({ where: { id: demoTripId } })).resolves.toMatchObject(
      {
        status: 'COMPLETED',
      },
    );
    await expect(
      prisma.tripStudent.findUnique({
        where: {
          dailyTripId_studentProfileId: {
            dailyTripId: demoTripId,
            studentProfileId: demoStudent.studentProfile.id,
          },
        },
      }),
    ).resolves.toMatchObject({ status: 'BOARDED', transportConfirmed: true });
  }, 30_000);
});
