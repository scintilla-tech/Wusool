import 'dotenv/config';
import { config as loadDotenv } from 'dotenv';
import { io } from 'socket.io-client';

loadDotenv({ path: '.env.demo.local', override: false });

async function main(): Promise<void> {
  const apiOrigin = process.env.WASL_API_ORIGIN ?? 'http://127.0.0.1:3100';
  const tenantCode = process.env.DEMO_TENANT_CODE;
  const phone = process.env.DEMO_DRIVER_PHONE;
  const password = process.env.DEMO_PASSWORD;
  const latitude = Number(process.env.SIMULATED_LATITUDE ?? '24.7500');
  const longitude = Number(process.env.SIMULATED_LONGITUDE ?? '46.6000');

  if (!tenantCode || !phone || !password) {
    throw new Error('Missing DEMO_TENANT_CODE, DEMO_DRIVER_PHONE, or DEMO_PASSWORD');
  }

  const loginResponse = await fetch(`${apiOrigin}/api/v1/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ tenantCode, phone, password }),
  });
  if (!loginResponse.ok) {
    throw new Error(`Driver login failed with HTTP ${loginResponse.status}`);
  }
  const login = (await loginResponse.json()) as {
    data?: { accessToken?: string };
  };
  const token = login.data?.accessToken;
  if (!token) throw new Error('Driver login response did not include an access token');

  await new Promise<void>((resolve, reject) => {
    const socket = io(apiOrigin, { transports: ['websocket'], auth: { token } });
    let finished = false;
    const finish = (error?: Error) => {
      if (finished) return;
      finished = true;
      clearTimeout(timeout);
      socket.disconnect();
      if (error) reject(error);
      else resolve();
    };
    const timeout = setTimeout(
      () => finish(new Error('Timed out waiting for the location broadcast')),
      10_000,
    );

    socket.on('connect', () => {
      socket.emit(
        'trip:location',
        { latitude, longitude, timestamp: Date.now() },
        (result: {
          success: boolean;
          tripId?: string;
          broadcast?: boolean;
          error?: { code: string; message: string };
        }) => {
          if (!result.success) {
            finish(new Error(`Location rejected: ${JSON.stringify(result.error)}`));
            return;
          }
          console.log(
            JSON.stringify({
              success: true,
              tripId: result.tripId,
              latitude,
              longitude,
              broadcast: result.broadcast,
            }),
          );
          finish();
        },
      );
    });
    socket.on('connect_error', (error) => finish(error));
    socket.on('trip:error', (error) => {
      finish(new Error(`Location rejected: ${JSON.stringify(error)}`));
    });
  });
}

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : 'Location simulation failed');
  process.exitCode = 1;
});
