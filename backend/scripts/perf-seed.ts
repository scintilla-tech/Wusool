/**
 * DEVELOPMENT-ONLY performance seed. Creates a realistic dataset for the
 * database performance audit (not for the product demo):
 *   1 tenant, 150 buses, 150 routes, 2,250 students, 150 drivers,
 *   assignments, attendance intents, 150 daily trips and 2,250 TripStudents.
 *
 * Run: DATABASE_URL=... npx tsx scripts/perf-seed.ts
 */
import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/utils/password';

const prisma = new PrismaClient();

const BUSES = 150;
const STUDENTS = 2250;
const PER_ROUTE = STUDENTS / BUSES; // 15

async function cleanup(tenantId: string): Promise<void> {
  const users = await prisma.user.findMany({ where: { tenantId }, select: { id: true } });
  const userIds = users.map((u) => u.id);
  await prisma.refreshSession.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.deviceToken.deleteMany({ where: { tenantId } });
  await prisma.notification.deleteMany({ where: { tenantId } });
  await prisma.userDocument.deleteMany({ where: { tenantId } });
  await prisma.auditLog.deleteMany({ where: { tenantId } });
  await prisma.tripStudent.deleteMany({ where: { tenantId } });
  await prisma.dailyTrip.deleteMany({ where: { tenantId } });
  await prisma.attendanceIntent.deleteMany({ where: { tenantId } });
  await prisma.studentAssignment.deleteMany({ where: { tenantId } });
  await prisma.driverAssignment.deleteMany({ where: { tenantId } });
  await prisma.supervisorBusAssignment.deleteMany({ where: { tenantId } });
  await prisma.routeNeighborhood.deleteMany({ where: { tenantId } });
  await prisma.studentProfile.deleteMany({ where: { tenantId } });
  await prisma.driverProfile.deleteMany({ where: { tenantId } });
  await prisma.supervisorProfile.deleteMany({ where: { tenantId } });
  await prisma.fieldSupervisorProfile.deleteMany({ where: { tenantId } });
  await prisma.user.deleteMany({ where: { tenantId } });
  await prisma.route.deleteMany({ where: { tenantId } });
  await prisma.bus.deleteMany({ where: { tenantId } });
  await prisma.neighborhood.deleteMany({ where: { tenantId } });
  await prisma.branch.deleteMany({ where: { tenantId } });
}

async function main(): Promise<void> {
  const started = Date.now();
  const existing = await prisma.tenant.findUnique({ where: { code: 'PERF' } });
  if (existing) {
    await cleanup(existing.id);
    await prisma.tenant.delete({ where: { id: existing.id } });
  }

  const tenant = await prisma.tenant.create({
    data: { code: 'PERF', name: 'Performance University' },
  });
  const t = tenant.id;
  const passwordHash = await hashPassword('PerfPass#1');

  const branch = await prisma.branch.create({
    data: {
      tenantId: t,
      name: 'Perf Campus',
      code: 'PERF',
      latitude: 24.72,
      longitude: 46.62,
      radius: 250,
    },
  });

  const hoods = await prisma.neighborhood.createManyAndReturn({
    data: Array.from({ length: 10 }, (_, i) => ({ tenantId: t, name: `Hood ${i + 1}` })),
    select: { id: true },
  });

  const buses = await prisma.bus.createManyAndReturn({
    data: Array.from({ length: BUSES }, (_, i) => ({
      tenantId: t,
      plateNumber: `PERF-${String(i + 1).padStart(4, '0')}`,
      capacity: 15,
    })),
    select: { id: true },
  });

  const routes = await prisma.route.createManyAndReturn({
    data: Array.from({ length: BUSES }, (_, i) => ({
      tenantId: t,
      name: `Route ${i + 1}`,
      code: `R-${String(i + 1).padStart(4, '0')}`,
      branchId: branch.id,
    })),
    select: { id: true },
  });

  const stopsData = routes.flatMap((r, i) =>
    [0, 1, 2].map((k) => ({
      tenantId: t,
      routeId: r.id,
      neighborhoodId: hoods[(i + k) % hoods.length].id,
      sequenceOrder: k,
    })),
  );
  await prisma.routeNeighborhood.createMany({ data: stopsData });

  // Drivers
  const driverUsers = await prisma.user.createManyAndReturn({
    data: Array.from({ length: BUSES }, (_, i) => ({
      tenantId: t,
      role: 'DRIVER' as const,
      firstName: 'Driver',
      lastName: String(i + 1),
      phone: `+9665${String(20000000 + i)}`,
      passwordHash,
    })),
    select: { id: true },
  });
  const driverProfiles = await prisma.driverProfile.createManyAndReturn({
    data: driverUsers.map((u, i) => ({
      userId: u.id,
      tenantId: t,
      employeeId: `D-${String(i + 1).padStart(4, '0')}`,
    })),
    select: { id: true },
  });
  await prisma.driverAssignment.createMany({
    data: driverProfiles.map((p, i) => ({
      tenantId: t,
      driverProfileId: p.id,
      busId: buses[i].id,
      isActive: true,
    })),
  });

  // Students
  const studentUsers = await prisma.user.createManyAndReturn({
    data: Array.from({ length: STUDENTS }, (_, i) => ({
      tenantId: t,
      role: 'STUDENT' as const,
      firstName: 'Student',
      lastName: String(i + 1),
      phone: `+9665${String(10000000 + i)}`,
      passwordHash,
    })),
    select: { id: true },
  });
  const studentProfiles = await prisma.studentProfile.createManyAndReturn({
    data: studentUsers.map((u, i) => ({
      userId: u.id,
      tenantId: t,
      studentId: `S-${String(i + 1).padStart(5, '0')}`,
      homeLatitude: 24.7 + (i % 100) * 0.001,
      homeLongitude: 46.6 + (i % 100) * 0.001,
    })),
    select: { id: true },
  });
  await prisma.studentAssignment.createMany({
    data: studentProfiles.map((p, i) => ({
      tenantId: t,
      studentProfileId: p.id,
      routeId: routes[Math.floor(i / PER_ROUTE)].id,
      isActive: true,
    })),
  });

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  await prisma.attendanceIntent.createMany({
    data: studentProfiles.map((p) => ({
      tenantId: t,
      studentProfileId: p.id,
      tripDate: today,
      intent: 'ATTENDING' as const,
    })),
  });

  // Today's trips + TripStudents
  const trips = await prisma.dailyTrip.createManyAndReturn({
    data: routes.map((r, i) => ({
      tenantId: t,
      routeId: r.id,
      busId: buses[i].id,
      driverProfileId: driverProfiles[i].id,
      tripDate: today,
      status: 'IN_PROGRESS' as const,
    })),
    select: { id: true },
  });
  const tripStudentsData = trips.flatMap((trip, ti) => {
    const start = ti * PER_ROUTE;
    return studentProfiles.slice(start, start + PER_ROUTE).map((p) => ({
      tenantId: t,
      dailyTripId: trip.id,
      studentProfileId: p.id,
      status: 'WAITING' as const,
    }));
  });
  await prisma.tripStudent.createMany({ data: tripStudentsData });

  console.log(
    `Perf seed complete in ${Date.now() - started}ms: tenant=${t} buses=${BUSES} students=${STUDENTS} trips=${trips.length}`,
  );
  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
