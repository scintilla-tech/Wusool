import { describe, expect, it, vi } from 'vitest';
import { Prisma, type PrismaClient } from '@prisma/client';
import { PeopleService } from '../src/modules/people/people.service';
import { peopleListQuerySchema } from '../src/modules/people/people.schemas';
import { StructureService } from '../src/modules/structure/structure.service';
import { AssignmentsService } from '../src/modules/assignments/assignments.service';
import { routeCreateSchema } from '../src/modules/structure/structure.schemas';

const student = {
  id: 'u1',
  role: 'STUDENT',
  firstName: 'سارة',
  lastName: 'العتيبي',
  phone: '+966500000201',
  email: 'sara@example.com',
  isActive: true,
  passwordHash: '$argon2id$secret',
  createdAt: new Date('2026-11-01T08:00:00Z'),
  studentProfile: {
    id: 'sp1',
    studentId: '441000001',
    studentAssignments: [{ route: { id: 'r1', name: 'North Loop', code: 'R1', isActive: true } }],
  },
  driverProfile: null,
  supervisorProfile: null,
  fieldSupervisorProfile: null,
};

const driver = {
  ...student,
  id: 'u2',
  role: 'DRIVER',
  firstName: 'Khalid',
  lastName: 'Saleh',
  phone: '+966500000301',
  email: null,
  passwordHash: null,
  studentProfile: null,
  driverProfile: {
    id: 'dp1',
    employeeId: 'DRV-301',
    nationalIdOrIqama: '2123456789',
    nationality: 'SA',
    joinDate: new Date('2025-11-01T00:00:00Z'),
    iqamaExpiry: null,
    driverAssignments: [],
  },
};

function peoplePrisma(user: unknown = student, overrides: Record<string, unknown> = {}) {
  const tx = {
    user: { update: vi.fn().mockResolvedValue({}) },
    studentProfile: { update: vi.fn().mockResolvedValue({}) },
    driverProfile: { update: vi.fn().mockResolvedValue({}) },
    supervisorProfile: { update: vi.fn().mockResolvedValue({}) },
    fieldSupervisorProfile: { update: vi.fn().mockResolvedValue({}) },
    refreshSession: { updateMany: vi.fn().mockResolvedValue({ count: 2 }) },
    deviceToken: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    studentAssignment: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    driverAssignment: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    supervisorBusAssignment: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
    auditLog: { create: vi.fn().mockResolvedValue({}) },
  };
  const prisma = {
    user: {
      findFirst: vi.fn().mockResolvedValue(user),
      findMany: vi.fn().mockResolvedValue([]),
      count: vi.fn().mockResolvedValue(0),
    },
    studentProfile: { findMany: vi.fn().mockResolvedValue([]) },
    driverProfile: { findMany: vi.fn().mockResolvedValue([]) },
    $transaction: vi.fn(async (fn: (client: typeof tx) => unknown) => fn(tx)),
    ...overrides,
  };
  return { prisma: prisma as unknown as PrismaClient, raw: prisma, tx };
}

const listQuery = { role: 'STUDENT' as const, status: 'all' as const, page: 1, limit: 30 };

describe('people directory', () => {
  it('pages through one role of the tenant, newest first, with counts per status', async () => {
    const { prisma, raw } = peoplePrisma();
    raw.user.findMany.mockResolvedValue([student]);
    raw.user.count.mockResolvedValue(7);

    const page = await new PeopleService(prisma).list('tenant1', { ...listQuery, page: 2 });

    const args = raw.user.findMany.mock.calls[0][0];
    expect(args.where.AND[0]).toEqual({ tenantId: 'tenant1', role: 'STUDENT' });
    expect(args).toMatchObject({ skip: 30, take: 30 });
    expect(args.orderBy).toEqual([{ createdAt: 'desc' }, { id: 'asc' }]);
    expect(page.counts).toEqual({ all: 7, active: 7, pending: 7, disabled: 7, unassigned: 7 });
    expect(page.items[0]).toEqual({
      id: 'u1',
      profileId: 'sp1',
      role: 'STUDENT',
      firstName: 'سارة',
      lastName: 'العتيبي',
      phone: '+966500000201',
      email: 'sara@example.com',
      number: '441000001',
      isActive: true,
      isActivated: true,
      route: { id: 'r1', name: 'North Loop', code: 'R1', isActive: true },
    });
    expect(JSON.stringify(page)).not.toContain('argon2');
  });

  it('searches every word in names, numbers and phones typed with a leading zero', async () => {
    const { prisma, raw } = peoplePrisma();

    await new PeopleService(prisma).list('tenant1', { ...listQuery, q: 'سارة ٠٥٠٠٠' });

    const [, nameWord, phoneWord] = raw.user.findMany.mock.calls[0][0].where.AND;
    expect(nameWord.OR).toContainEqual({ firstName: { contains: 'سارة', mode: 'insensitive' } });
    expect(nameWord.OR).not.toContainEqual(expect.objectContaining({ phone: expect.anything() }));
    expect(phoneWord.OR).toContainEqual({ phone: { contains: '5000' } });
    expect(phoneWord.OR).toContainEqual({
      studentProfile: { studentId: { contains: '05000', mode: 'insensitive' } },
    });
  });

  it('finds students without a route, and the students of one route', async () => {
    const { prisma, raw } = peoplePrisma();
    const service = new PeopleService(prisma);

    await service.list('tenant1', { ...listQuery, status: 'unassigned' });
    await service.list('tenant1', { ...listQuery, routeId: 'r1' });

    expect(raw.user.findMany.mock.calls[0][0].where.AND.at(-1)).toEqual({
      isActive: true,
      studentProfile: {
        studentAssignments: { none: { isActive: true, routeId: { not: null } } },
      },
    });
    expect(raw.user.findMany.mock.calls[1][0].where.AND).toContainEqual({
      studentProfile: { studentAssignments: { some: { isActive: true, routeId: 'r1' } } },
    });
  });

  it('only accepts filters that fit the role', () => {
    const parse = (query: Record<string, string>) => peopleListQuerySchema.safeParse(query);
    expect(parse({ role: 'STUDENT', routeId: 'none' }).success).toBe(true);
    expect(parse({ role: 'DRIVER', busId: 'none' }).success).toBe(true);
    expect(parse({ role: 'DRIVER', routeId: 'none' }).success).toBe(false);
    expect(parse({ role: 'STUDENT', busId: 'none' }).success).toBe(false);
    expect(parse({ role: 'FIELD_SUPERVISOR', status: 'unassigned' }).success).toBe(false);
    expect(parse({ role: 'UNIVERSITY_ADMIN' }).success).toBe(false);
  });

  it('opens a person with the values the edit form shows', async () => {
    const { prisma } = peoplePrisma(driver);

    const person = await new PeopleService(prisma).get('tenant1', 'u2');

    expect(person).toMatchObject({ isActivated: false, bus: null, number: 'DRV-301' });
    expect(person.row).toEqual({
      firstName: 'Khalid',
      lastName: 'Saleh',
      phone: '0500000301',
      employeeId: 'DRV-301',
      nationalIdOrIqama: '2123456789',
      nationality: 'SA',
      joinDate: '2025-11-01',
    });
  });

  it('only opens students and staff of the same tenant', async () => {
    const { prisma, raw } = peoplePrisma(null);

    await expect(new PeopleService(prisma).get('tenant1', 'admin')).rejects.toMatchObject({
      statusCode: 404,
    });
    expect(raw.user.findFirst.mock.calls[0][0].where).toEqual({
      id: 'admin',
      tenantId: 'tenant1',
      role: { in: ['STUDENT', 'DRIVER', 'SUPERVISOR', 'FIELD_SUPERVISOR'] },
    });
  });
});

describe('editing a person', () => {
  const edited = {
    firstName: 'سارة',
    lastName: 'القحطاني',
    phone: '0500000209',
    studentId: '441000009',
  };

  it('saves new values, clears an emptied email, and records who changed them', async () => {
    const { prisma, raw, tx } = peoplePrisma();

    const result = await new PeopleService(prisma).update('tenant1', 'admin1', 'u1', edited);

    expect(result.saved).toBe(true);
    // Values in use are looked up on other accounts only.
    expect(raw.user.findMany.mock.calls[0][0].where).toMatchObject({ id: { not: 'u1' } });
    expect(raw.studentProfile.findMany.mock.calls[0][0].where).toMatchObject({
      userId: { not: 'u1' },
    });
    expect(tx.user.update).toHaveBeenCalledWith({
      where: { id: 'u1' },
      data: { firstName: 'سارة', lastName: 'القحطاني', phone: '+966500000209', email: null },
    });
    expect(tx.studentProfile.update).toHaveBeenCalledWith({
      where: { userId: 'u1' },
      data: { studentId: '441000009' },
    });
    expect(tx.auditLog.create.mock.calls[0][0].data).toMatchObject({
      action: 'PERSON_UPDATED',
      actorUserId: 'admin1',
      entityId: 'u1',
    });
  });

  it('reports problems per field and saves nothing', async () => {
    const { prisma, raw, tx } = peoplePrisma(student, {});
    raw.user.findMany.mockResolvedValue([{ phone: '+966500000209' }]);

    const service = new PeopleService(prisma);
    expect(await service.update('tenant1', 'admin1', 'u1', edited)).toEqual({
      saved: false,
      issues: [{ field: 'phone', code: 'PHONE_TAKEN' }],
    });
    expect(await service.update('tenant1', 'admin1', 'u1', { ...edited, phone: '12' })).toEqual({
      saved: false,
      issues: [{ field: 'phone', code: 'INVALID_PHONE' }],
    });
    expect(tx.user.update).not.toHaveBeenCalled();
  });

  it('reports a value another admin took meanwhile against its field', async () => {
    const { prisma } = peoplePrisma(student, {
      $transaction: vi.fn().mockRejectedValue(
        new Prisma.PrismaClientKnownRequestError('unique', {
          code: 'P2002',
          clientVersion: 'test',
          meta: { target: ['tenantId', 'studentId'] },
        }),
      ),
    });

    expect(await new PeopleService(prisma).update('tenant1', 'admin1', 'u1', edited)).toEqual({
      saved: false,
      issues: [{ field: 'studentId', code: 'ID_TAKEN' }],
    });
  });
});

describe('disabling and enabling', () => {
  it('stops sign-in, signs the person out and takes them off their bus', async () => {
    const { prisma, tx } = peoplePrisma(driver);

    await new PeopleService(prisma).disable('tenant1', 'admin1', 'u2');

    expect(tx.user.update).toHaveBeenCalledWith({ where: { id: 'u2' }, data: { isActive: false } });
    expect(tx.refreshSession.updateMany.mock.calls[0][0].where).toEqual({
      userId: 'u2',
      revokedAt: null,
    });
    expect(tx.deviceToken.updateMany.mock.calls[0][0].where).toEqual({
      userId: 'u2',
      isActive: true,
    });
    expect(tx.driverAssignment.updateMany).toHaveBeenCalledWith({
      where: { tenantId: 'tenant1', driverProfileId: 'dp1', isActive: true },
      data: { isActive: false },
    });
    expect(tx.auditLog.create.mock.calls[0][0].data).toMatchObject({
      action: 'PERSON_DISABLED',
      metadata: { role: 'DRIVER', endedAssignments: 1 },
    });
  });

  it('changes nothing when the account is already in the asked state', async () => {
    const { prisma, raw } = peoplePrisma(student);
    const service = new PeopleService(prisma);

    await service.enable('tenant1', 'admin1', 'u1');
    expect(raw.$transaction).not.toHaveBeenCalled();

    raw.user.findFirst.mockResolvedValue({ ...student, isActive: false });
    await service.disable('tenant1', 'admin1', 'u1');
    expect(raw.$transaction).not.toHaveBeenCalled();
  });

  it('lets a disabled person sign in again', async () => {
    const { prisma, tx } = peoplePrisma({ ...student, isActive: false });

    await new PeopleService(prisma).enable('tenant1', 'admin1', 'u1');

    expect(tx.user.update).toHaveBeenCalledWith({ where: { id: 'u1' }, data: { isActive: true } });
    expect(tx.auditLog.create.mock.calls[0][0].data.action).toBe('PERSON_ENABLED');
  });
});

describe('buses and routes', () => {
  const bus = {
    id: 'b1',
    tenantId: 'tenant1',
    plateNumber: 'ABC 1234',
    name: null,
    capacity: 30,
    isActive: false,
    driverAssignments: [],
    supervisorBusAssignments: [],
  };

  function structurePrisma(overrides: Record<string, unknown> = {}) {
    const tx = {
      bus: { update: vi.fn().mockResolvedValue({}), updateMany: vi.fn() },
      route: { create: vi.fn().mockResolvedValue({ id: 'r9' }), update: vi.fn() },
      routeNeighborhood: { createMany: vi.fn(), deleteMany: vi.fn() },
      driverAssignment: { updateMany: vi.fn() },
      supervisorBusAssignment: { updateMany: vi.fn() },
      studentAssignment: { updateMany: vi.fn() },
    };
    const prisma = {
      bus: { findFirst: vi.fn().mockResolvedValue(bus) },
      route: {
        findFirst: vi.fn().mockResolvedValue({
          id: 'r9',
          name: 'مسار 3',
          branch: null,
          routeNeighborhoods: [],
          _count: { studentAssignments: 0 },
        }),
      },
      neighborhood: { count: vi.fn().mockResolvedValue(2) },
      $transaction: vi.fn(async (fn: (client: typeof tx) => unknown) => fn(tx)),
      ...overrides,
    };
    return { prisma: prisma as unknown as PrismaClient, tx };
  }

  it('takes a bus out of service along with its driver and supervisor', async () => {
    const { prisma, tx } = structurePrisma();

    const result = await new StructureService(prisma).archiveBus('tenant1', 'b1');

    const ended = { where: { tenantId: 'tenant1', busId: 'b1', isActive: true } };
    expect(tx.driverAssignment.updateMany).toHaveBeenCalledWith({
      ...ended,
      data: { isActive: false },
    });
    expect(tx.supervisorBusAssignment.updateMany).toHaveBeenCalledWith({
      ...ended,
      data: { isActive: false },
    });
    expect(result).toMatchObject({ id: 'b1', driver: null, supervisor: null });
  });

  it('refuses a plate number another bus has', async () => {
    const { prisma } = structurePrisma({
      $transaction: vi.fn().mockRejectedValue(
        new Prisma.PrismaClientKnownRequestError('unique', {
          code: 'P2002',
          clientVersion: 'test',
        }),
      ),
    });

    await expect(
      new StructureService(prisma).updateBus('tenant1', 'b1', { plateNumber: 'XYZ 1' }),
    ).rejects.toMatchObject({ statusCode: 409, code: 'PLATE_TAKEN' });
  });

  it('creates a route with its stops in the order given', async () => {
    const { prisma, tx } = structurePrisma();
    const stops = ['c000000000000000000000002', 'c000000000000000000000001'];

    const route = await new StructureService(prisma).createRoute('tenant1', {
      name: 'مسار 3',
      stopIds: stops,
    });

    expect(tx.routeNeighborhood.createMany).toHaveBeenCalledWith({
      data: [
        { tenantId: 'tenant1', routeId: 'r9', neighborhoodId: stops[0], sequenceOrder: 0 },
        { tenantId: 'tenant1', routeId: 'r9', neighborhoodId: stops[1], sequenceOrder: 1 },
      ],
    });
    expect(route).toMatchObject({ id: 'r9', studentCount: 0 });
    expect(routeCreateSchema.safeParse({ name: 'مسار 3 (الشمال)' }).success).toBe(true);
    // Arabic diacritics such as shadda are part of names.
    expect(routeCreateSchema.safeParse({ name: 'مسار المعدّل' }).success).toBe(true);
    // The demo data's neighborhoods have readable ids.
    expect(routeCreateSchema.safeParse({ name: 'R', stopIds: ['demo-AlNarjis'] }).success).toBe(
      true,
    );
    expect(routeCreateSchema.safeParse({ name: 'R', stopIds: ['../x'] }).success).toBe(false);
  });

  it('takes the students off a route taken out of service', async () => {
    const { prisma, tx } = structurePrisma();

    await new StructureService(prisma).archiveRoute('tenant1', 'r9');

    expect(tx.studentAssignment.updateMany).toHaveBeenCalledWith({
      where: { tenantId: 'tenant1', routeId: 'r9', isActive: true },
      data: { isActive: false },
    });
    // Its bus no longer runs it.
    expect(tx.bus.updateMany).toHaveBeenCalledWith({
      where: { tenantId: 'tenant1', routeId: 'r9' },
      data: { routeId: null },
    });
  });
});

describe('putting students on a route', () => {
  function assignPrisma(found: number, onRoute: string[] = []) {
    const prisma = {
      route: {
        findFirst: vi.fn().mockResolvedValue({ id: 'r1', branchId: 'branch1' }),
      },
      studentProfile: { count: vi.fn().mockResolvedValue(found) },
      studentAssignment: {
        findMany: vi
          .fn()
          .mockResolvedValue(onRoute.map((studentProfileId) => ({ studentProfileId }))),
        updateMany: vi.fn().mockReturnValue('end'),
        createMany: vi.fn().mockReturnValue('create'),
      },
      $transaction: vi.fn().mockResolvedValue([]),
    };
    return { prisma: prisma as unknown as PrismaClient, raw: prisma };
  }

  it('moves students from other routes and leaves those already on it', async () => {
    const { prisma, raw } = assignPrisma(3, ['sp2']);

    const result = await new AssignmentsService(prisma).assignStudentsToRoute('tenant1', {
      routeId: 'r1',
      studentProfileIds: ['sp1', 'sp2', 'sp3', 'sp1'],
    });

    expect(result).toEqual({ assigned: 2 });
    expect(raw.studentProfile.count.mock.calls[0][0].where).toMatchObject({
      id: { in: ['sp1', 'sp2', 'sp3'] },
      user: { isActive: true },
    });
    expect(raw.studentAssignment.updateMany.mock.calls[0][0].where.studentProfileId).toEqual({
      in: ['sp1', 'sp3'],
    });
    expect(raw.studentAssignment.createMany.mock.calls[0][0].data[0]).toEqual({
      tenantId: 'tenant1',
      studentProfileId: 'sp1',
      routeId: 'r1',
      branchId: 'branch1',
      isActive: true,
    });
  });

  it('refuses when any student is missing or disabled', async () => {
    const { prisma, raw } = assignPrisma(1);

    await expect(
      new AssignmentsService(prisma).assignStudentsToRoute('tenant1', {
        routeId: 'r1',
        studentProfileIds: ['sp1', 'sp-disabled'],
      }),
    ).rejects.toMatchObject({ statusCode: 422, code: 'INVALID_STUDENTS' });
    expect(raw.$transaction).not.toHaveBeenCalled();
  });
});
