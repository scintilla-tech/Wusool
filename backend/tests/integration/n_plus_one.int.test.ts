import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { PrismaClient } from '@prisma/client';

import { StudentsService } from '../../src/modules/students/students.service';
import { EmployeesService } from '../../src/modules/employees/employees.service';
import { AssignmentsService } from '../../src/modules/assignments/assignments.service';
import { StructureService } from '../../src/modules/structure/structure.service';

/**
 * Database-backed N+1 regression tests. Run with:
 *   RUN_DB_TESTS=1 DATABASE_URL=... npm test
 * Requires the perf dataset (scripts/perf-seed.ts). Skipped otherwise.
 */
const runDb = process.env.RUN_DB_TESTS === '1';

interface Counted {
  client: PrismaClient;
  state: { count: number };
  dispose: () => Promise<void>;
}

function countingPrisma(): Counted {
  const state = { count: 0 };
  const base = new PrismaClient();
  const client = base.$extends({
    query: {
      $allModels: {
        async $allOperations({ args, query }) {
          state.count += 1;
          return query(args);
        },
      },
    },
  }) as unknown as PrismaClient;
  return { client, state, dispose: () => base.$disconnect() };
}

describe.skipIf(!runDb)('N+1 regression (query count must not scale with result size)', () => {
  let base: PrismaClient;
  let tenantId: string | null = null;

  beforeAll(async () => {
    base = new PrismaClient();
    const tenant = await base.tenant.findUnique({ where: { code: 'PERF' } });
    tenantId = tenant?.id ?? null;
  });

  afterAll(async () => {
    await base.$disconnect();
  });

  async function measure(fn: (client: PrismaClient) => Promise<unknown>): Promise<number> {
    const { client, state, dispose } = countingPrisma();
    state.count = 0;
    await fn(client);
    const count = state.count;
    await dispose();
    return count;
  }

  it('student list query count is constant for page size 5 vs 100', async () => {
    if (!tenantId) return;
    const small = await measure((c) => new StudentsService(c).list(tenantId!, 1, 5));
    const large = await measure((c) => new StudentsService(c).list(tenantId!, 1, 100));
    expect(small).toBe(large);
    expect(small).toBeLessThanOrEqual(4);
  });

  it('employee list query count is constant for page size 5 vs 100', async () => {
    if (!tenantId) return;
    const small = await measure((c) => new EmployeesService(c).list(tenantId!, 'DRIVER', 1, 5));
    const large = await measure((c) => new EmployeesService(c).list(tenantId!, 'DRIVER', 1, 100));
    expect(small).toBe(large);
    expect(small).toBeLessThanOrEqual(4);
  });

  it('student assignment list query count is constant for page size 5 vs 100', async () => {
    if (!tenantId) return;
    const small = await measure((c) =>
      new AssignmentsService(c).listStudentAssignments(tenantId!, 1, 5),
    );
    const large = await measure((c) =>
      new AssignmentsService(c).listStudentAssignments(tenantId!, 1, 100),
    );
    expect(small).toBe(large);
    expect(small).toBeLessThanOrEqual(4);
  });

  it('route list (nested stops) query count is constant for page size 5 vs 50', async () => {
    if (!tenantId) return;
    const small = await measure((c) =>
      new StructureService(c).listRoutes(tenantId!, { page: 1, limit: 5 }),
    );
    const large = await measure((c) =>
      new StructureService(c).listRoutes(tenantId!, { page: 1, limit: 50 }),
    );
    expect(small).toBe(large);
    expect(small).toBeLessThanOrEqual(4);
  });
});
