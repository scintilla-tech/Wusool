/**
 * DEVELOPMENT-ONLY demo seed. Creates realistic fictional data for the WASL MVP
 * demo. No real personal information. Run with: DATABASE_URL=... npm run prisma:seed
 *
 * Demo credentials (all passwords fictional):
 *   Admin:       phone +966501111111  password AdminPass#1
 *   Driver 1:    phone +966550000001  password DriverPass#1
 *   Driver 2:    phone +966550000002  password DriverPass#2
 *   Supervisor:  phone +966550000003  password SuperPass#1
 *   Students:    phone +9665510000NN  password Student#123  (NN = 01..08)
 */
import { PrismaClient, type Role } from '@prisma/client';
import { hashPassword } from '../src/utils/password';

const prisma = new PrismaClient();

async function upsertTenant() {
  return prisma.tenant.upsert({
    where: { code: 'KSU' },
    update: {},
    create: { code: 'KSU', name: 'King Saud University' },
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
  const buses = ['KSU-1001', 'KSU-1002', 'KSU-1003', 'KSU-1004'];
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
    lastName: 'KSU',
    phone: '+966501111111',
    password: 'AdminPass#1',
  });

  const driver1User = await upsertUser(t, {
    role: 'DRIVER',
    firstName: 'Khalid',
    lastName: 'Ali',
    phone: '+966550000001',
    password: 'DriverPass#1',
  });
  const driver2User = await upsertUser(t, {
    role: 'DRIVER',
    firstName: 'Omar',
    lastName: 'Salem',
    phone: '+966550000002',
    password: 'DriverPass#2',
  });
  const supUser = await upsertUser(t, {
    role: 'SUPERVISOR',
    firstName: 'Noura',
    lastName: 'Fahad',
    phone: '+966550000003',
    password: 'SuperPass#1',
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
    data: { tenantId: t, driverProfileId: driver1.id, busId: busIds['KSU-1001'], isActive: true },
  });
  await prisma.driverAssignment.create({
    data: { tenantId: t, driverProfileId: driver2.id, busId: busIds['KSU-1002'], isActive: true },
  });
  await prisma.supervisorBusAssignment.updateMany({
    where: { tenantId: t },
    data: { isActive: false },
  });
  await prisma.supervisorBusAssignment.create({
    data: {
      tenantId: t,
      supervisorProfileId: supervisor.id,
      busId: busIds['KSU-1001'],
      isActive: true,
    },
  });

  // Students
  const studentNames = ['Sara', 'Layla', 'Hessa', 'Abeer', 'Reem', 'Nada', 'Dana', 'Lina'];
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  await prisma.studentAssignment.updateMany({ where: { tenantId: t }, data: { isActive: false } });

  for (const [i, first] of studentNames.entries()) {
    const phone = `+9665510000${String(i + 1).padStart(2, '0')}`;
    const user = await upsertUser(t, {
      role: 'STUDENT',
      firstName: first,
      lastName: 'Mohammed',
      phone,
      password: 'Student#123',
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
    await prisma.attendanceIntent.upsert({
      where: { studentProfileId_tripDate: { studentProfileId: profile.id, tripDate: today } },
      update: { intent: 'ATTENDING' },
      create: { tenantId: t, studentProfileId: profile.id, tripDate: today, intent: 'ATTENDING' },
    });
  }

  console.log('Demo seed complete.');
  console.log('Credentials:');
  console.log('  Admin      +966501111111 / AdminPass#1');
  console.log('  Driver 1   +966550000001 / DriverPass#1');
  console.log('  Driver 2   +966550000002 / DriverPass#2');
  console.log('  Supervisor +966550000003 / SuperPass#1');
  console.log('  Students   +9665510000NN / Student#123');

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
