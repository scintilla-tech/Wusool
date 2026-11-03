import { io, type Socket } from 'socket.io-client';

const baseUrl = (process.env.API_BASE_URL ?? '').replace(/\/$/, '');
const password = process.env.DEMO_PASSWORD ?? '';

if (!baseUrl.startsWith('https://')) {
  throw new Error('API_BASE_URL must be the HTTPS service origin (without /api/v1)');
}
if (!password) throw new Error('DEMO_PASSWORD is required');

type Json = Record<string, any>;

async function request(path: string, options: RequestInit = {}, token?: string): Promise<Json> {
  const response = await fetch(`${baseUrl}/api/v1${path}`, {
    ...options,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  });
  const body = (await response.json()) as Json;
  if (!response.ok || body.success !== true) {
    throw new Error(
      `${options.method ?? 'GET'} ${path} failed (${response.status}): ${JSON.stringify(body)}`,
    );
  }
  return body.data as Json;
}

async function login(phone: string): Promise<string> {
  const data = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ tenantCode: 'KKU', phone, password }),
  });
  if (typeof data.accessToken !== 'string') throw new Error(`Login returned no token for ${phone}`);
  return data.accessToken;
}

function openSocket(token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const socket = io(baseUrl, {
      transports: ['websocket'],
      auth: { token },
      reconnection: false,
      timeout: 15_000,
    });
    const timer = setTimeout(() => reject(new Error('Socket.IO connection timed out')), 20_000);
    socket.once('connect', () => {
      clearTimeout(timer);
      resolve(socket);
    });
    socket.once('connect_error', (error) => {
      clearTimeout(timer);
      reject(error);
    });
  });
}

function waitForLocation(socket: Socket, tripId: string): Promise<Json> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error('Student did not receive location event')),
      20_000,
    );
    socket.on('trip:location', (payload: Json) => {
      if (payload.tripId !== tripId) return;
      clearTimeout(timer);
      resolve(payload);
    });
  });
}

async function publishLocation(socket: Socket, latitude: number, longitude: number): Promise<Json> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error('Driver location was not acknowledged')),
      20_000,
    );
    socket.emit('trip:location', { latitude, longitude, timestamp: Date.now() }, (result: Json) => {
      clearTimeout(timer);
      if (result.success !== true)
        reject(new Error(`Location rejected: ${JSON.stringify(result)}`));
      else resolve(result);
    });
  });
}

async function main(): Promise<void> {
  console.log('1/9 health');
  const health = await fetch(`${baseUrl}/health/ready`);
  if (!health.ok) throw new Error(`Readiness failed: ${health.status}`);

  console.log('2/9 demo logins');
  const [studentToken, driverToken, supervisorToken] = await Promise.all([
    login('+966500000101'),
    login('+966500000102'),
    login('+966500000103'),
  ]);

  console.log('3/9 student attendance intent');
  await request(
    '/attendance/today/OUTBOUND',
    { method: 'PUT', body: JSON.stringify({ intent: 'ATTENDING' }) },
    studentToken,
  );

  const trips = (await request('/driver/today/trips', {}, driverToken)) as unknown as Json[];
  const trip = trips.find((item) => item.direction === 'OUTBOUND' && item.status === 'SCHEDULED');
  if (!trip?.id) throw new Error('No scheduled outbound demo trip; redeploy/reseed the demo first');
  const student = (trip.tripStudents as Json[]).find(
    (item) => item.studentProfile?.user?.phone === '+966500000101',
  );
  if (!student?.studentProfileId)
    throw new Error('Demo student is not assigned to the outbound trip');

  console.log('4/9 sockets over WSS');
  const studentSocket = await openSocket(studentToken);
  const driverSocket = await openSocket(driverToken);
  try {
    console.log('5/9 start trip');
    await request(`/driver/${trip.id}/start`, { method: 'POST' }, driverToken);

    console.log('6/9 live bus location reaches student');
    const received = waitForLocation(studentSocket, trip.id as string);
    await publishLocation(driverSocket, 18.2465, 42.5117);
    const location = await received;
    if (location.latitude !== 18.2465 || location.longitude !== 42.5117) {
      throw new Error(`Student received unexpected location: ${JSON.stringify(location)}`);
    }
    const studentTrip = await request('/students/me/trip', {}, studentToken);
    if (studentTrip.latestLocation?.latitude !== 18.2465) {
      throw new Error('Student REST view does not expose the latest bus location');
    }

    console.log('7/9 board student / record transport attendance');
    await request(
      `/driver/${trip.id}/students/${student.studentProfileId}`,
      { method: 'PATCH', body: JSON.stringify({ status: 'BOARDED' }) },
      driverToken,
    );

    console.log('8/9 supervisor view');
    const buses = (await request('/supervisor/buses', {}, supervisorToken)) as unknown as Json[];
    const visible = buses.some((bus) => bus.trip?.id === trip.id && bus.counts?.boarded >= 1);
    if (!visible) throw new Error('Supervisor view did not show the boarded student');

    console.log('9/9 complete trip');
    await request(`/driver/${trip.id}/complete`, { method: 'POST' }, driverToken);
  } finally {
    studentSocket.close();
    driverSocket.close();
  }

  console.log(
    'Cloud demo scenario passed: login, attendance, start, WSS location, student view, supervisor view, completion.',
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
