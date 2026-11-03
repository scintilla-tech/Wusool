import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { createTestApp, mockPrisma, testEnv } from './helpers';
import { signAccessToken } from '../src/utils/token';

type Method = 'get' | 'post' | 'put' | 'patch' | 'delete';

interface EndpointCase {
  method: Method;
  path: string;
  expectedWithoutAuth: number;
}

const id = 'c123456789012345678901234';

const routeSources = [
  ['src/modules/health/health.routes.ts', '/health'],
  ['src/modules/auth/auth.routes.ts', '/api/v1/auth'],
  ['src/modules/students/students.self.routes.ts', '/api/v1/students'],
  ['src/modules/students/students.routes.ts', '/api/v1/students'],
  ['src/modules/structure/structure.routes.ts', '/api/v1/structure'],
  ['src/modules/employees/employees.routes.ts', '/api/v1/employees'],
  ['src/modules/attendance/attendance.routes.ts', '/api/v1/attendance'],
  ['src/modules/assignments/assignments.routes.ts', '/api/v1/assignments'],
  ['src/modules/trips/trips.routes.ts', '/api/v1/trips'],
  ['src/modules/trips/driver.routes.ts', '/api/v1/driver'],
  ['src/modules/supervisor/supervisor.routes.ts', '/api/v1/supervisor'],
  ['src/modules/admin/admin.routes.ts', '/api/v1/admin'],
  ['src/modules/platform/platform.routes.ts', '/api/v1/platform'],
  ['src/modules/devices/devices.routes.ts', '/api/v1/devices'],
  ['src/modules/notifications/notifications.routes.ts', '/api/v1/notifications'],
  ['src/modules/documents/documents.routes.ts', '/api/v1/documents'],
  ['src/modules/imports/imports.routes.ts', '/api/v1/imports'],
  ['src/modules/people/people.routes.ts', '/api/v1/people'],
] as const;

function discoverRoutesFromSource(): string[] {
  return routeSources.flatMap(([file, prefix]) => {
    const source = readFileSync(resolve(process.cwd(), file), 'utf8');
    return [...source.matchAll(/router\.(get|post|put|patch|delete)\(\s*['`]([^'`]+)['`]/g)].map(
      ([, method, suffix]) => {
        const fullPath = suffix === '/' ? prefix : `${prefix}${suffix}`;
        return `${method.toUpperCase()} ${fullPath.replace(/:[^/]+/g, id)}`;
      },
    );
  });
}

/** Source-of-truth route inventory used to ensure no endpoint is omitted from the audit. */
export const endpointInventory: EndpointCase[] = [
  { method: 'get', path: '/health/live', expectedWithoutAuth: 200 },
  { method: 'get', path: '/health/ready', expectedWithoutAuth: 200 },
  { method: 'post', path: '/api/v1/auth/login', expectedWithoutAuth: 400 },
  { method: 'post', path: '/api/v1/auth/activation/request', expectedWithoutAuth: 400 },
  { method: 'post', path: '/api/v1/auth/activation/complete', expectedWithoutAuth: 400 },
  { method: 'post', path: '/api/v1/auth/refresh', expectedWithoutAuth: 400 },
  { method: 'post', path: '/api/v1/auth/logout', expectedWithoutAuth: 400 },
  { method: 'post', path: '/api/v1/auth/logout-all', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/auth/me', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/students/register', expectedWithoutAuth: 400 },
  { method: 'post', path: '/api/v1/students/verify', expectedWithoutAuth: 400 },
  { method: 'get', path: '/api/v1/students/me', expectedWithoutAuth: 401 },
  { method: 'patch', path: '/api/v1/students/me', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/students/me/trip', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/students', expectedWithoutAuth: 401 },
  { method: 'get', path: `/api/v1/students/${id}`, expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/students', expectedWithoutAuth: 401 },
  { method: 'patch', path: `/api/v1/students/${id}`, expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/students/${id}`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/structure/branches', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/structure/branches', expectedWithoutAuth: 401 },
  { method: 'patch', path: `/api/v1/structure/branches/${id}`, expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/structure/branches/${id}`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/structure/neighborhoods', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/structure/neighborhoods', expectedWithoutAuth: 401 },
  { method: 'patch', path: `/api/v1/structure/neighborhoods/${id}`, expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/structure/neighborhoods/${id}`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/structure/buses', expectedWithoutAuth: 401 },
  { method: 'get', path: `/api/v1/structure/buses/${id}`, expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/structure/buses', expectedWithoutAuth: 401 },
  { method: 'patch', path: `/api/v1/structure/buses/${id}`, expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/structure/buses/${id}`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/structure/routes', expectedWithoutAuth: 401 },
  { method: 'get', path: `/api/v1/structure/routes/${id}`, expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/structure/routes', expectedWithoutAuth: 401 },
  { method: 'patch', path: `/api/v1/structure/routes/${id}`, expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/structure/routes/${id}`, expectedWithoutAuth: 401 },
  { method: 'put', path: `/api/v1/structure/routes/${id}/stops`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/employees', expectedWithoutAuth: 401 },
  { method: 'get', path: `/api/v1/employees/${id}`, expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/employees', expectedWithoutAuth: 401 },
  { method: 'patch', path: `/api/v1/employees/${id}`, expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/employees/${id}`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/attendance/today', expectedWithoutAuth: 401 },
  { method: 'put', path: '/api/v1/attendance/today', expectedWithoutAuth: 401 },
  { method: 'put', path: `/api/v1/attendance/today/${id}`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/assignments/students', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/assignments/students', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/assignments/students/batch', expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/assignments/students/${id}`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/assignments/drivers', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/assignments/drivers', expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/assignments/drivers/${id}`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/assignments/supervisors', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/assignments/supervisors', expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/assignments/supervisors/${id}`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/trips', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/trips', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/driver/today', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/driver/today/trips', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/driver/bus', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/driver/trips', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/driver/route-options', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/driver/neighborhoods', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/driver/route', expectedWithoutAuth: 401 },
  { method: 'patch', path: '/api/v1/driver/route', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/driver/absences', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/driver/absences', expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/driver/absences/${id}`, expectedWithoutAuth: 401 },
  { method: 'put', path: `/api/v1/driver/${id}/attendance/${id}`, expectedWithoutAuth: 401 },
  { method: 'post', path: `/api/v1/driver/${id}/attendance/close`, expectedWithoutAuth: 401 },
  { method: 'post', path: `/api/v1/driver/${id}/start`, expectedWithoutAuth: 401 },
  { method: 'patch', path: `/api/v1/driver/${id}/students/${id}`, expectedWithoutAuth: 401 },
  { method: 'post', path: `/api/v1/driver/${id}/complete`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/supervisor/buses', expectedWithoutAuth: 401 },
  { method: 'get', path: `/api/v1/supervisor/buses/${id}/drivers`, expectedWithoutAuth: 401 },
  { method: 'post', path: `/api/v1/supervisor/buses/${id}/cover`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/admin/dashboard', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/admin/settings', expectedWithoutAuth: 401 },
  { method: 'patch', path: '/api/v1/admin/settings', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/admin/holidays', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/admin/holidays', expectedWithoutAuth: 401 },
  { method: 'patch', path: `/api/v1/admin/holidays/${id}`, expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/admin/holidays/${id}`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/platform/tenants', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/platform/tenants', expectedWithoutAuth: 401 },
  { method: 'patch', path: `/api/v1/platform/tenants/${id}`, expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/devices', expectedWithoutAuth: 401 },
  { method: 'delete', path: '/api/v1/devices', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/notifications', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/notifications/unread-count', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/notifications/read-all', expectedWithoutAuth: 401 },
  { method: 'patch', path: `/api/v1/notifications/${id}/read`, expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/documents', expectedWithoutAuth: 401 },
  { method: 'get', path: `/api/v1/documents/${id}/url`, expectedWithoutAuth: 401 },
  { method: 'get', path: `/api/v1/documents/${id}/file`, expectedWithoutAuth: 401 },
  { method: 'get', path: `/api/v1/imports/templates/${id}`, expectedWithoutAuth: 404 },
  { method: 'post', path: '/api/v1/imports/read-file', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/imports/check', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/imports/submit', expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/imports/drafts', expectedWithoutAuth: 401 },
  { method: 'post', path: '/api/v1/imports/drafts', expectedWithoutAuth: 401 },
  { method: 'get', path: `/api/v1/imports/drafts/${id}`, expectedWithoutAuth: 401 },
  { method: 'put', path: `/api/v1/imports/drafts/${id}`, expectedWithoutAuth: 401 },
  { method: 'delete', path: `/api/v1/imports/drafts/${id}`, expectedWithoutAuth: 401 },
  { method: 'get', path: '/api/v1/people', expectedWithoutAuth: 401 },
  { method: 'get', path: `/api/v1/people/${id}`, expectedWithoutAuth: 401 },
  { method: 'put', path: `/api/v1/people/${id}`, expectedWithoutAuth: 401 },
  { method: 'post', path: `/api/v1/people/${id}/disable`, expectedWithoutAuth: 401 },
  { method: 'post', path: `/api/v1/people/${id}/enable`, expectedWithoutAuth: 401 },
];

describe('complete HTTP endpoint inventory', () => {
  it('contains the exact discovered endpoint count', () => {
    expect(endpointInventory).toHaveLength(110);
  });

  it('matches every route declaration discovered from the source files', () => {
    const declared = endpointInventory
      .map(({ method, path }) => `${method.toUpperCase()} ${path}`)
      .sort();
    expect(discoverRoutesFromSource().sort()).toEqual(declared);
  });

  it.each(endpointInventory)(
    '$method $path returns $expectedWithoutAuth without authentication/valid public input',
    async ({ method, path, expectedWithoutAuth }) => {
      const response = await request(createTestApp())[method](path).send({});
      expect(response.status).toBe(expectedWithoutAuth);
      if (path.startsWith('/health/')) expect(response.body.status).toBe('ok');
      else expect(response.body).toHaveProperty('success');
    },
  );

  const protectedEndpoints = endpointInventory.filter(
    (endpoint) => endpoint.expectedWithoutAuth === 401,
  );

  it.each(protectedEndpoints)(
    '$method $path rejects an expired access token',
    async ({ method, path }) => {
      const expired = signAccessToken(
        { sub: 'u1', type: 'access' },
        testEnv.JWT_ACCESS_SECRET,
        '1ms',
      );
      await new Promise((resolve) => setTimeout(resolve, 5));
      const response = await request(createTestApp())
        [method](path)
        .set('Authorization', `Bearer ${expired}`)
        .send({});
      expect(response.status).toBe(401);
      expect(response.body.error.code).toBe('UNAUTHORIZED');
    },
  );

  const studentDeniedEndpoints = protectedEndpoints.filter(({ path }) => {
    const adminStudentPath =
      path === '/api/v1/students' ||
      (path.startsWith('/api/v1/students/') && !path.startsWith('/api/v1/students/me'));
    return (
      adminStudentPath ||
      [
        '/api/v1/structure/',
        '/api/v1/employees',
        '/api/v1/assignments/',
        '/api/v1/trips',
        '/api/v1/driver/',
        '/api/v1/supervisor/',
        '/api/v1/admin/',
        '/api/v1/platform/',
        '/api/v1/imports/',
        '/api/v1/people',
      ].some((prefix) => path.startsWith(prefix))
    );
  });

  it.each(studentDeniedEndpoints)(
    '$method $path rejects an authenticated student with insufficient permissions',
    async ({ method, path }) => {
      const base = mockPrisma() as unknown as Record<string, unknown>;
      const prisma = {
        ...base,
        user: {
          findUnique: async () => ({
            id: 'student-user',
            tenantId: 'tenant1',
            role: 'STUDENT',
            isActive: true,
            tenant: { isActive: true },
          }),
        },
      } as unknown as PrismaClient;
      const token = signAccessToken(
        { sub: 'student-user', type: 'access' },
        testEnv.JWT_ACCESS_SECRET,
        '15m',
      );
      const response = await request(createTestApp(prisma))
        [method](path)
        .set('Authorization', `Bearer ${token}`)
        .send({});
      expect(response.status).toBe(403);
      expect(response.body.error.code).toBe('FORBIDDEN');
    },
  );
});
