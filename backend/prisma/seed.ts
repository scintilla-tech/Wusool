/**
 * DEVELOPMENT-ONLY demo seed. Creates realistic fictional data for the WASL MVP
 * demo. No real personal information. It requires an explicit opt-in, local
 * database URL, and credentials from ignored local environment files.
 */
import { PrismaClient, type Role } from '@prisma/client';
import { config as loadDotenv } from 'dotenv';
import { todayDate } from '../src/utils/date';
import { hashPassword } from '../src/utils/password';

loadDotenv({ path: '.env.demo.local', override: false });
loadDotenv({ path: '.env.attendance-demo.local', override: false });

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required local demo setting: ${name}`);
  return value;
}

const nodeEnv = process.env.NODE_ENV;
const localSeed = ['development', 'test'].includes(nodeEnv ?? '');
const remoteStagingSeed =
  nodeEnv === 'staging' &&
  process.env.ALLOW_DEMO_DEPLOYMENT === 'true' &&
  process.env.ALLOW_REMOTE_DEMO_SEED === 'true';
if ((!localSeed && !remoteStagingSeed) || process.env.ALLOW_DEMO_SEED !== 'true') {
  throw new Error(
    'Demo seed refused: use a local development/test database, or explicitly enable the staging-only remote demo seed',
  );
}

const databaseUrl = required('DATABASE_URL');
const databaseHost = new URL(databaseUrl).hostname;
if (!['127.0.0.1', 'localhost', '::1'].includes(databaseHost) && !remoteStagingSeed) {
  throw new Error(`Demo seed refused for non-local database host: ${databaseHost}`);
}

const prisma = new PrismaClient();

const DEMO_PASSWORD = process.env.ATTENDANCE_DEMO_PASSWORD ?? required('DEMO_PASSWORD');
const legacyPassword = (name: string): string =>
  remoteStagingSeed ? (process.env[name] ?? DEMO_PASSWORD) : required(name);
const LEGACY_ADMIN_PASSWORD = legacyPassword('LEGACY_ADMIN_PASSWORD');
const LEGACY_DRIVER_PASSWORD = legacyPassword('LEGACY_DRIVER_PASSWORD');
const LEGACY_SUPERVISOR_PASSWORD = legacyPassword('LEGACY_SUPERVISOR_PASSWORD');
const LEGACY_STUDENT_PASSWORD = legacyPassword('LEGACY_STUDENT_PASSWORD');

async function upsertTenant() {
  return prisma.tenant.upsert({
    where: { code: 'KKU' },
    update: {},
    create: { code: 'KKU', name: 'King Khalid University' },
  });
}

async function upsertUser(
  tenantId: string,
  data: {
    role: Role;
    firstName: string;
    lastName: string;
    phone: string;
    password: string;
    email?: string;
  },
) {
  const passwordHash = await hashPassword(data.password);
  return prisma.user.upsert({
    where: { tenantId_phone: { tenantId, phone: data.phone } },
    update: { passwordHash },
    create: {
      tenantId,
      role: data.role,
      firstName: data.firstName,
      lastName: data.lastName,
      phone: data.phone,
      email: data.email ?? null,
      passwordHash,
      isActive: true,
    },
  });
}

/** Idempotent upsert for a persistent per-role demo identity (deterministic id). */
async function upsertDemoUser(
  id: string,
  data: {
    role: Role;
    phone: string;
    email?: string;
    tenantId: string | null;
    passwordHash: string;
  },
) {
  const base = {
    role: data.role,
    firstName: 'Nejood',
    lastName: 'Demo',
    phone: data.phone,
    email: data.email ?? null,
    tenantId: data.tenantId,
    passwordHash: data.passwordHash,
    isActive: true,
  };
  return prisma.user.upsert({ where: { id }, update: base, create: { id, ...base } });
}

async function upsertDemoAttendance(
  tenantId: string,
  routeId: string,
  studentProfileId: string,
  actorUserId: string,
  operationalDate: Date,
  direction: 'OUTBOUND' | 'RETURN' = 'OUTBOUND',
) {
  const session = await prisma.attendanceSession.upsert({
    where: {
      tenantId_routeId_operationalDate_direction: {
        tenantId,
        routeId,
        operationalDate,
        direction,
      },
    },
    update: {},
    create: { tenantId, routeId, operationalDate, direction },
  });
  return prisma.attendanceIntent.upsert({
    where: {
      attendanceSessionId_studentProfileId: {
        attendanceSessionId: session.id,
        studentProfileId,
      },
    },
    update: { intent: 'ATTENDING', actorUserId, actorRole: 'STUDENT' },
    create: {
      tenantId,
      attendanceSessionId: session.id,
      studentProfileId,
      operationalDate,
      direction,
      intent: 'ATTENDING',
      source: 'STUDENT_SELF_REGISTRATION',
      actorUserId,
      actorRole: 'STUDENT',
    },
  });
}

async function main(): Promise<void> {
  const tenant = await upsertTenant();
  const t = tenant.id;

  // Branches
  const branchMain = await prisma.branch.upsert({
    where: { tenantId_code: { tenantId: t, code: 'MAIN' } },
    update: {},
    create: {
      tenantId: t,
      name: 'Main Campus',
      code: 'MAIN',
      latitude: 24.7218,
      longitude: 46.6277,
      radius: 250,
    },
  });
  const branchNorth = await prisma.branch.upsert({
    where: { tenantId_code: { tenantId: t, code: 'NORTH' } },
    update: {},
    create: {
      tenantId: t,
      name: 'North Campus',
      code: 'NORTH',
      latitude: 24.789,
      longitude: 46.65,
      radius: 250,
    },
  });

  // Neighborhoods
  const neighborhoods = ['AlNarjis', 'AlMalqa', 'AlYasmin', 'AlQayrawan'];
  const hoods: Record<string, string> = {};
  for (const name of neighborhoods) {
    const hood = await prisma.neighborhood.upsert({
      where: { id: `demo-${name}` },
      update: {},
      create: { id: `demo-${name}`, tenantId: t, name },
    });
    hoods[name] = hood.id;
  }

  // Routes + stops
  const route1 = await prisma.route.upsert({
    where: { tenantId_code: { tenantId: t, code: 'R1' } },
    update: {},
    create: { tenantId: t, name: 'North Loop', code: 'R1', branchId: branchMain.id },
  });
  const route2 = await prisma.route.upsert({
    where: { tenantId_code: { tenantId: t, code: 'R2' } },
    update: {},
    create: { tenantId: t, name: 'East Loop', code: 'R2', branchId: branchNorth.id },
  });
  for (const [routeId, names] of [
    [route1.id, ['AlNarjis', 'AlMalqa']],
    [route2.id, ['AlYasmin', 'AlQayrawan']],
  ] as Array<[string, string[]]>) {
    await prisma.routeNeighborhood.deleteMany({ where: { routeId } });
    for (const [i, name] of names.entries()) {
      await prisma.routeNeighborhood.create({
        data: { tenantId: t, routeId, neighborhoodId: hoods[name], sequenceOrder: i },
      });
    }
  }

  // Buses
  const buses = ['KKU-1001', 'KKU-1002', 'KKU-1003', 'KKU-1004'];
  const busIds: Record<string, string> = {};
  for (const plate of buses) {
    const bus = await prisma.bus.upsert({
      where: { tenantId_plateNumber: { tenantId: t, plateNumber: plate } },
      update: {},
      create: { tenantId: t, plateNumber: plate, capacity: 15 },
    });
    busIds[plate] = bus.id;
  }

  // Employees
  await upsertUser(t, {
    role: 'UNIVERSITY_ADMIN',
    firstName: 'Admin',
    lastName: 'KKU',
    phone: '+966501111111',
    password: LEGACY_ADMIN_PASSWORD,
  });

  const driver1User = await upsertUser(t, {
    role: 'DRIVER',
    firstName: 'Khalid',
    lastName: 'Ali',
    phone: '+966550000001',
    password: LEGACY_DRIVER_PASSWORD,
  });
  const driver2User = await upsertUser(t, {
    role: 'DRIVER',
    firstName: 'Omar',
    lastName: 'Salem',
    phone: '+966550000002',
    password: LEGACY_DRIVER_PASSWORD,
  });
  const supUser = await upsertUser(t, {
    role: 'SUPERVISOR',
    firstName: 'Noura',
    lastName: 'Fahad',
    phone: '+966550000003',
    password: LEGACY_SUPERVISOR_PASSWORD,
  });

  const driver1 = await prisma.driverProfile.upsert({
    where: { userId: driver1User.id },
    update: {},
    create: { userId: driver1User.id, tenantId: t, employeeId: 'D001', nationality: 'Saudi' },
  });
  const driver2 = await prisma.driverProfile.upsert({
    where: { userId: driver2User.id },
    update: {},
    create: { userId: driver2User.id, tenantId: t, employeeId: 'D002', nationality: 'Saudi' },
  });
  const supervisor = await prisma.supervisorProfile.upsert({
    where: { userId: supUser.id },
    update: {},
    create: { userId: supUser.id, tenantId: t, employeeId: 'S001', nationality: 'Saudi' },
  });

  // Driver/supervisor assignments to buses
  await prisma.driverAssignment.updateMany({ where: { tenantId: t }, data: { isActive: false } });
  await prisma.driverAssignment.create({
    data: { tenantId: t, driverProfileId: driver1.id, busId: busIds['KKU-1001'], isActive: true },
  });
  await prisma.driverAssignment.create({
    data: { tenantId: t, driverProfileId: driver2.id, busId: busIds['KKU-1002'], isActive: true },
  });
  await prisma.supervisorBusAssignment.updateMany({
    where: { tenantId: t },
    data: { isActive: false },
  });
  await prisma.supervisorBusAssignment.create({
    data: {
      tenantId: t,
      supervisorProfileId: supervisor.id,
      busId: busIds['KKU-1001'],
      isActive: true,
    },
  });

  // Students
  const studentNames = ['Sara', 'Layla', 'Hessa', 'Abeer', 'Reem', 'Nada', 'Dana', 'Lina'];
  const today = todayDate();
  await prisma.studentAssignment.updateMany({ where: { tenantId: t }, data: { isActive: false } });

  for (const [i, first] of studentNames.entries()) {
    const phone = `+9665510000${String(i + 1).padStart(2, '0')}`;
    const user = await upsertUser(t, {
      role: 'STUDENT',
      firstName: first,
      lastName: 'Mohammed',
      phone,
      password: LEGACY_STUDENT_PASSWORD,
    });
    const profile = await prisma.studentProfile.upsert({
      where: { userId: user.id },
      update: {},
      create: {
        userId: user.id,
        tenantId: t,
        studentId: `S${String(i + 1).padStart(4, '0')}`,
        homeLatitude: 24.75 + i * 0.01,
        homeLongitude: 46.6 + i * 0.01,
      },
    });
    const route = i % 2 === 0 ? route1.id : route2.id;
    await prisma.studentAssignment.create({
      data: { tenantId: t, studentProfileId: profile.id, routeId: route, isActive: true },
    });
    await upsertDemoAttendance(t, route, profile.id, user.id, today);
  }

  // ---------------------------------------------------------------------------
  // Persistent per-role demo identities (DEVELOPMENT / DEMO ONLY).
  // One account per role so RBAC and object-level authorization can be tested.
  // Idempotent: deterministic ids + upserts (re-running never duplicates).
  // ---------------------------------------------------------------------------
  const demoPasswordHash = await hashPassword(DEMO_PASSWORD);

  // 1. Student
  const demoStudentUser = await upsertDemoUser('demo-user-student-nejood', {
    role: 'STUDENT',
    phone: '+966500000101',
    email: 'nejood.student@example.test',
    tenantId: t,
    passwordHash: demoPasswordHash,
  });
  const demoStudentProfile = await prisma.studentProfile.upsert({
    where: { userId: demoStudentUser.id },
    update: { tenantId: t, studentId: '440000001', homeLatitude: 24.756, homeLongitude: 46.612 },
    create: {
      userId: demoStudentUser.id,
      tenantId: t,
      studentId: '440000001',
      homeLatitude: 24.756,
      homeLongitude: 46.612,
    },
  });
  await prisma.studentAssignment.updateMany({
    where: { tenantId: t, studentProfileId: demoStudentProfile.id, isActive: true },
    data: { isActive: false },
  });
  await prisma.studentAssignment.upsert({
    where: { id: 'demo-sa-nejood' },
    update: { routeId: route1.id, branchId: branchMain.id, isActive: true },
    create: {
      id: 'demo-sa-nejood',
      tenantId: t,
      studentProfileId: demoStudentProfile.id,
      routeId: route1.id,
      branchId: branchMain.id,
      isActive: true,
    },
  });
  await upsertDemoAttendance(t, route1.id, demoStudentProfile.id, demoStudentUser.id, today);

  // 2. Driver (active driver of demo bus KKU-1003)
  const demoDriverUser = await upsertDemoUser('demo-user-driver-nejood', {
    role: 'DRIVER',
    phone: '+966500000102',
    tenantId: t,
    passwordHash: demoPasswordHash,
  });
  const demoDriverProfile = await prisma.driverProfile.upsert({
    where: { userId: demoDriverUser.id },
    update: { tenantId: t, employeeId: 'DRV-NEJOOD-01', nationality: 'Saudi' },
    create: {
      userId: demoDriverUser.id,
      tenantId: t,
      employeeId: 'DRV-NEJOOD-01',
      nationality: 'Saudi',
    },
  });
  await prisma.driverAssignment.updateMany({
    where: { tenantId: t, busId: busIds['KKU-1003'], isActive: true },
    data: { isActive: false },
  });
  await prisma.driverAssignment.upsert({
    where: { id: 'demo-da-nejood' },
    update: { driverProfileId: demoDriverProfile.id, busId: busIds['KKU-1003'], isActive: true },
    create: {
      id: 'demo-da-nejood',
      tenantId: t,
      driverProfileId: demoDriverProfile.id,
      busId: busIds['KKU-1003'],
      isActive: true,
    },
  });

  // 3. Supervisor (same demo bus KKU-1003)
  const demoSupervisorUser = await upsertDemoUser('demo-user-supervisor-nejood', {
    role: 'SUPERVISOR',
    phone: '+966500000103',
    tenantId: t,
    passwordHash: demoPasswordHash,
  });
  const demoSupervisorProfile = await prisma.supervisorProfile.upsert({
    where: { userId: demoSupervisorUser.id },
    update: { tenantId: t, employeeId: 'SUP-NEJOOD-01', nationality: 'Saudi' },
    create: {
      userId: demoSupervisorUser.id,
      tenantId: t,
      employeeId: 'SUP-NEJOOD-01',
      nationality: 'Saudi',
    },
  });
  await prisma.supervisorBusAssignment.updateMany({
    where: { tenantId: t, busId: busIds['KKU-1003'], isActive: true },
    data: { isActive: false },
  });
  await prisma.supervisorBusAssignment.upsert({
    where: { id: 'demo-sba-nejood' },
    update: {
      supervisorProfileId: demoSupervisorProfile.id,
      busId: busIds['KKU-1003'],
      isActive: true,
    },
    create: {
      id: 'demo-sba-nejood',
      tenantId: t,
      supervisorProfileId: demoSupervisorProfile.id,
      busId: busIds['KKU-1003'],
      isActive: true,
    },
  });

  // 4. Field supervisor (tenant-wide operational access; no per-bus assignment model)
  const demoFsupUser = await upsertDemoUser('demo-user-fsup-nejood', {
    role: 'FIELD_SUPERVISOR',
    phone: '+966500000104',
    tenantId: t,
    passwordHash: demoPasswordHash,
  });
  await prisma.fieldSupervisorProfile.upsert({
    where: { userId: demoFsupUser.id },
    update: { tenantId: t, employeeId: 'FSUP-NEJOOD-01', nationality: 'Saudi' },
    create: {
      userId: demoFsupUser.id,
      tenantId: t,
      employeeId: 'FSUP-NEJOOD-01',
      nationality: 'Saudi',
    },
  });

  // 5. University admin (same demo tenant)
  await upsertDemoUser('demo-user-admin-nejood', {
    role: 'UNIVERSITY_ADMIN',
    phone: '+966500000105',
    tenantId: t,
    passwordHash: demoPasswordHash,
  });

  // 6. Platform super admin (platform-level: tenantId MUST be null)
  await upsertDemoUser('demo-user-platform-nejood', {
    role: 'PLATFORM_SUPER_ADMIN',
    phone: '+966500000106',
    tenantId: null,
    passwordHash: demoPasswordHash,
  });

  // Today's trip for the demo driver's bus/route so driver + student flows are testable.
  const demoTrip = await prisma.dailyTrip.upsert({
    where: { id: 'demo-trip-nejood' },
    update: {
      tripDate: today,
      direction: 'OUTBOUND',
      status: 'SCHEDULED',
      startedAt: null,
      completedAt: null,
    },
    create: {
      id: 'demo-trip-nejood',
      tenantId: t,
      routeId: route1.id,
      busId: busIds['KKU-1003'],
      driverProfileId: demoDriverProfile.id,
      tripDate: today,
      direction: 'OUTBOUND',
      status: 'SCHEDULED',
    },
  });
  await prisma.attendanceSession.updateMany({
    where: {
      dailyTripId: demoTrip.id,
      NOT: { operationalDate: today, direction: 'OUTBOUND' },
    },
    data: { dailyTripId: null },
  });
  await prisma.attendanceSession.update({
    where: {
      tenantId_routeId_operationalDate_direction: {
        tenantId: t,
        routeId: route1.id,
        operationalDate: today,
        direction: 'OUTBOUND',
      },
    },
    data: {
      dailyTripId: demoTrip.id,
      status: 'OPEN',
      closedAt: null,
      closedByDriverProfileId: null,
    },
  });
  const demoReturnTrip = await prisma.dailyTrip.upsert({
    where: { id: 'demo-trip-return-nejood' },
    update: {
      tripDate: today,
      direction: 'RETURN',
      status: 'SCHEDULED',
      startedAt: null,
      completedAt: null,
    },
    create: {
      id: 'demo-trip-return-nejood',
      tenantId: t,
      routeId: route1.id,
      busId: busIds['KKU-1003'],
      driverProfileId: demoDriverProfile.id,
      tripDate: today,
      direction: 'RETURN',
      status: 'SCHEDULED',
    },
  });
  await prisma.attendanceSession.updateMany({
    where: {
      dailyTripId: demoReturnTrip.id,
      NOT: { operationalDate: today, direction: 'RETURN' },
    },
    data: { dailyTripId: null },
  });
  await prisma.attendanceSession.upsert({
    where: {
      tenantId_routeId_operationalDate_direction: {
        tenantId: t,
        routeId: route1.id,
        operationalDate: today,
        direction: 'RETURN',
      },
    },
    update: {
      dailyTripId: demoReturnTrip.id,
      status: 'OPEN',
      closedAt: null,
      closedByDriverProfileId: null,
    },
    create: {
      tenantId: t,
      routeId: route1.id,
      operationalDate: today,
      direction: 'RETURN',
      dailyTripId: demoReturnTrip.id,
    },
  });
  const routeAssignments = await prisma.studentAssignment.findMany({
    where: { tenantId: t, routeId: route1.id, isActive: true },
    select: { studentProfileId: true },
  });
  const attending = await prisma.attendanceIntent.findMany({
    where: {
      tenantId: t,
      operationalDate: today,
      direction: 'OUTBOUND',
      intent: 'ATTENDING',
      studentProfileId: { in: routeAssignments.map((a) => a.studentProfileId) },
    },
    select: { studentProfileId: true },
  });
  for (const intent of attending) {
    await prisma.tripStudent.upsert({
      where: {
        dailyTripId_studentProfileId: {
          dailyTripId: demoTrip.id,
          studentProfileId: intent.studentProfileId,
        },
      },
      update: {
        status: 'WAITING',
        boardedAt: null,
        missedAt: null,
        transportConfirmed: false,
      },
      create: {
        tenantId: t,
        dailyTripId: demoTrip.id,
        studentProfileId: intent.studentProfileId,
        status: 'WAITING',
      },
    });
  }
  for (const assignment of routeAssignments) {
    await prisma.tripStudent.upsert({
      where: {
        dailyTripId_studentProfileId: {
          dailyTripId: demoReturnTrip.id,
          studentProfileId: assignment.studentProfileId,
        },
      },
      update: { status: 'WAITING', boardedAt: null, missedAt: null, transportConfirmed: false },
      create: {
        tenantId: t,
        dailyTripId: demoReturnTrip.id,
        studentProfileId: assignment.studentProfileId,
        status: 'WAITING',
      },
    });
  }

  console.log('Demo seed complete.');
  console.log('Persistent per-role demo identities created for tenant KKU.');
  console.log('  STUDENT            +966500000101  (university id 440000001)');
  console.log('  DRIVER             +966500000102  (employee DRV-NEJOOD-01)');
  console.log('  SUPERVISOR         +966500000103  (employee SUP-NEJOOD-01)');
  console.log('  FIELD_SUPERVISOR   +966500000104  (employee FSUP-NEJOOD-01)');
  console.log('  UNIVERSITY_ADMIN   +966500000105  (employee ADMIN-NEJOOD-01)');
  console.log('  PLATFORM_SUPER_ADMIN +966500000106 (tenantId = null)');
  console.log('Passwords remain only in the ignored local demo credential file.');

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
