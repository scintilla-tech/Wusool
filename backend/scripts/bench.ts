/**
 * DEVELOPMENT-ONLY benchmark. Measures latency (p50/p95) and DB query counts for
 * the critical read paths against the perf dataset (scripts/perf-seed.ts).
 *
 * Run: DATABASE_URL=... npx tsx scripts/bench.ts
 */
import { PrismaClient } from '@prisma/client';
import { StudentsService } from '../src/modules/students/students.service';
import { EmployeesService } from '../src/modules/employees/employees.service';
import { AssignmentsService } from '../src/modules/assignments/assignments.service';
import { StructureService } from '../src/modules/structure/structure.service';
import { TripService } from '../src/modules/trips/trips.service';
import { AttendanceService } from '../src/modules/attendance/attendance.service';
import { StudentSelfService } from '../src/modules/students/students.self.service';
import { OtpService } from '../src/modules/otp/otp.service';
import { MockOtpProvider } from '../src/providers/otp';

const ITERATIONS = 60;

function percentile(sorted: number[], p: number): number {
  const idx = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
  return sorted[idx];
}

async function bench(label: string, fn: () => Promise<unknown>): Promise<void> {
  // warmup
  await fn();
  const times: number[] = [];
  for (let i = 0; i < ITERATIONS; i++) {
    const start = performance.now();
    await fn();
    times.push(performance.now() - start);
  }
  times.sort((a, b) => a - b);
  const p50 = percentile(times, 50);
  const p95 = percentile(times, 95);
  const p99 = percentile(times, 99);
  console.log(
    `${label.padEnd(34)} p50=${p50.toFixed(2)}ms p95=${p95.toFixed(2)}ms p99=${p99.toFixed(2)}ms`,
  );
}

async function countQueries(fn: (client: PrismaClient) => Promise<unknown>): Promise<number> {
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
  state.count = 0;
  await fn(client);
  await base.$disconnect();
  return state.count;
}

async function main(): Promise<void> {
  const prisma = new PrismaClient();
  const tenant = await prisma.tenant.findUnique({ where: { code: 'PERF' } });
  if (!tenant) throw new Error('Run scripts/perf-seed.ts first');
  const tenantId = tenant.id;

  const driver = await prisma.user.findFirst({ where: { tenantId, role: 'DRIVER' } });
  const student = await prisma.user.findFirst({ where: { tenantId, role: 'STUDENT' } });
  if (!driver || !student) throw new Error('Perf users missing');

  const students = new StudentsService(prisma);
  const employees = new EmployeesService(prisma);
  const assignments = new AssignmentsService(prisma);
  const structure = new StructureService(prisma);
  const trips = new TripService(prisma);
  const attendance = new AttendanceService(prisma, '23:59');
  const self = new StudentSelfService(prisma, new OtpService(new MockOtpProvider()), false);

  console.log(`\nBenchmark (${ITERATIONS} iterations) — tenant ${tenantId}\n`);

  await bench('admin student list (limit 20)', () => students.list(tenantId, 1, 20));
  await bench('admin employee list (limit 20)', () => employees.list(tenantId, 'DRIVER', 1, 20));
  await bench('admin bus list (limit 20)', () =>
    structure.listBuses(tenantId, { page: 1, limit: 20 }),
  );
  await bench('route list (limit 20, nested)', () =>
    structure.listRoutes(tenantId, { page: 1, limit: 20 }),
  );
  await bench('student assignment list (limit 20)', () =>
    assignments.listStudentAssignments(tenantId, 1, 20),
  );
  await bench('driver assigned trip (today)', () => trips.getDriverToday(tenantId, driver.id));
  await bench('student attendance (today)', () => attendance.getTodayForUser(tenantId, student.id));
  await bench('student self profile', () => self.getMe(student.id));
  await bench('attendance set intent (write)', () =>
    attendance.setIntentForUser(tenantId, student.id, 'ATTENDING'),
  );

  console.log('\nDB query counts (per single call):');
  console.log(
    '  admin student list (limit 20)     ',
    await countQueries((c) => new StudentsService(c).list(tenantId, 1, 20)),
  );
  console.log(
    '  admin student list (limit 100)    ',
    await countQueries((c) => new StudentsService(c).list(tenantId, 1, 100)),
  );
  console.log(
    '  route list (limit 50, nested)     ',
    await countQueries((c) => new StructureService(c).listRoutes(tenantId, { page: 1, limit: 50 })),
  );
  console.log(
    '  driver assigned trip (today)      ',
    await countQueries((c) => new TripService(c).getDriverToday(tenantId, driver.id)),
  );

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
