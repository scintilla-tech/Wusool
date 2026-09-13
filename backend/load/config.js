// Shared k6 configuration for WASL load tests.
export const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:3100/api/v1';

export const TENANT_CODE = __ENV.WASL_TENANT || 'KSU';

// Development demo credentials (see backend/prisma/seed.ts). Never use real accounts.
export const CREDENTIALS = {
  admin: {
    phone: __ENV.WASL_ADMIN_PHONE || '+966501111111',
    password: __ENV.WASL_ADMIN_PASSWORD || 'AdminPass#1',
  },
  driver: {
    phone: __ENV.WASL_DRIVER_PHONE || '+966550000001',
    password: __ENV.WASL_DRIVER_PASSWORD || 'DriverPass#1',
  },
  student: {
    phone: __ENV.WASL_STUDENT_PHONE || '+966551000001',
    password: __ENV.WASL_STUDENT_PASSWORD || 'Student#123',
  },
};

export function login(http, creds) {
  const res = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({ tenantCode: TENANT_CODE, phone: creds.phone, password: creds.password }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  try {
    return res.json('data.accessToken');
  } catch {
    return null;
  }
}

export function authHeaders(token) {
  return { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } };
}
