import { describe, expect, it, vi } from 'vitest';
import { Prisma, type PrismaClient } from '@prisma/client';
import { AbsenceService } from '../src/modules/absences/absence.service';
import { CoverService } from '../src/modules/supervisor/cover.service';
import { HolidayService } from '../src/modules/admin/holiday.service';
import { AdminService } from '../src/modules/admin/admin.service';
import { DriverRouteService } from '../src/modules/trips/driver-route.service';
import type { StructureService } from '../src/modules/structure/structure.service';
import type { NotificationService } from '../src/modules/notifications/notification.service';
import { dayPhrase } from '../src/modules/notifications/trip-messages';
import { dateOnly } from '../src/utils/date';

const DAY = 86_400_000;
const today = dateOnly(new Date());
const tomorrow = new Date(today.getTime() + DAY);
const iso = (date: Date) => date.toISOString().slice(0, 10);

function notifications() {
  const send = vi.fn().mockResolvedValue(undefined);
  const sendToAll = vi.fn(async (ids: string[], payload: unknown) => {
    for (const id of ids) await send(id, payload);
  });
  return { service: { send, sendToAll } as unknown as NotificationService, send };
}

const khalid = {
  id: 'dp-khalid',
  user: { firstName: 'Khalid', lastName: 'Ali' },
  driverAssignments: [{ bus: { id: 'bus1', plateNumber: 'KKU-1001', name: null } }],
};

describe('days a driver cannot drive', () => {
  function absencePrisma(overrides: Record<string, unknown> = {}) {
    const prisma = {
      driverProfile: { findFirst: vi.fn().mockResolvedValue(khalid) },
      supervisorBusAssignment: {
        findMany: vi.fn().mockResolvedValue([{ supervisorProfile: { userId: 'u-noura' } }]),
      },
      driverAbsence: {
        create: vi.fn(async ({ data }) => ({
          id: 'abs1',
          date: data.date,
          note: data.note,
          busId: data.busId,
          driverProfile: { id: 'dp-khalid', user: khalid.user },
          coverDriverProfile: null,
        })),
        findFirst: vi.fn(),
        delete: vi.fn(),
      },
      auditLog: { create: vi.fn() },
      ...overrides,
    };
    return { prisma: prisma as unknown as PrismaClient, raw: prisma };
  }

  it('tells the bus supervisor which day and why', async () => {
    const { prisma, raw } = absencePrisma();
    const { service, send } = notifications();

    const absence = await new AbsenceService(prisma, service).report('tenant1', 'u-khalid', {
      date: tomorrow,
      note: ' موعد طبي ',
    });

    expect(absence).toMatchObject({ date: iso(tomorrow), note: 'موعد طبي', coverName: null });
    expect(raw.driverAbsence.create.mock.calls[0][0].data).toMatchObject({
      driverProfileId: 'dp-khalid',
      busId: 'bus1',
      date: tomorrow,
    });
    expect(send).toHaveBeenCalledWith('u-noura', {
      type: 'DRIVER_ABSENT',
      title: 'Khalid Ali لن يقود غداً',
      body: 'KKU-1001: موعد طبي. اختاري سائقاً بديلاً.',
    });
    expect(raw.auditLog.create.mock.calls[0][0].data.action).toBe('DRIVER_ABSENCE_REPORTED');
  });

  it('refuses past days, far days, twice the same day, and buses without a supervisor', async () => {
    const { service } = notifications();
    const absences = new AbsenceService(absencePrisma().prisma, service);
    const yesterday = new Date(today.getTime() - DAY);
    const far = new Date(today.getTime() + 61 * DAY);
    await expect(absences.report('t', 'u', { date: yesterday })).rejects.toMatchObject({
      code: 'INVALID_DATE',
    });
    await expect(absences.report('t', 'u', { date: far })).rejects.toMatchObject({
      code: 'INVALID_DATE',
    });

    const twice = absencePrisma({
      driverAbsence: {
        create: vi.fn().mockRejectedValue(
          new Prisma.PrismaClientKnownRequestError('unique', {
            code: 'P2002',
            clientVersion: 't',
          }),
        ),
      },
    });
    await expect(
      new AbsenceService(twice.prisma, service).report('t', 'u', { date: tomorrow }),
    ).rejects.toMatchObject({ code: 'ABSENCE_EXISTS' });

    const alone = absencePrisma({
      supervisorBusAssignment: { findMany: vi.fn().mockResolvedValue([]) },
    });
    await expect(
      new AbsenceService(alone.prisma, service).report('t', 'u', { date: tomorrow }),
    ).rejects.toMatchObject({ code: 'NO_SUPERVISOR' });
  });

  it('can be taken back until a cover is chosen', async () => {
    const { prisma, raw } = absencePrisma();
    const { service, send } = notifications();
    const absences = new AbsenceService(prisma, service);
    const bus = { id: 'bus1', plateNumber: 'KKU-1001', name: null };

    raw.driverAbsence.findFirst.mockResolvedValue({
      id: 'abs1',
      date: tomorrow,
      coverDriverProfileId: 'dp-omar',
      bus,
    });
    await expect(absences.cancel('tenant1', 'u-khalid', 'abs1')).rejects.toMatchObject({
      code: 'COVER_CHOSEN',
    });

    raw.driverAbsence.findFirst.mockResolvedValue({
      id: 'abs1',
      date: tomorrow,
      coverDriverProfileId: null,
      bus,
    });
    await absences.cancel('tenant1', 'u-khalid', 'abs1');
    expect(raw.driverAbsence.delete).toHaveBeenCalledWith({ where: { id: 'abs1' } });
    expect(send).toHaveBeenCalledWith(
      'u-noura',
      expect.objectContaining({ title: 'Khalid Ali سيقود غداً' }),
    );
  });

  it('names days the way people say them', () => {
    expect(dayPhrase(today, today)).toEqual({ of: 'اليوم', on: 'اليوم' });
    expect(dayPhrase(tomorrow, today)).toEqual({ of: 'الغد', on: 'غداً' });
    const tuesday = new Date('2026-11-10T00:00:00Z');
    expect(dayPhrase(tuesday, new Date('2026-11-02T00:00:00Z'))).toEqual({
      of: 'الثلاثاء 10 نوفمبر',
      on: 'يوم الثلاثاء 10 نوفمبر',
    });
  });
});

describe('choosing a cover ahead of the day', () => {
  const people = {
    'dp-khalid': { userId: 'u-khalid', firstName: 'Khalid', lastName: 'Ali' },
    'dp-omar': { userId: 'u-omar', firstName: 'Omar', lastName: 'Salem' },
    'dp-saad': { userId: 'u-saad', firstName: 'Saad', lastName: 'Cover' },
  };
  const profile = (id: keyof typeof people, bus: unknown = null) => ({
    id,
    user: {
      id: people[id].userId,
      firstName: people[id].firstName,
      lastName: people[id].lastName,
      phone: '',
    },
    driverAssignments: bus ? [{ bus }] : [],
  });

  function planPrisma(absence: Record<string, unknown> | null, otherAbsences: unknown[] = []) {
    const prisma = {
      supervisorBusAssignment: {
        findFirst: vi
          .fn()
          .mockResolvedValue({ bus: { id: 'bus1', plateNumber: 'KKU-1001', name: null } }),
      },
      driverProfile: {
        findFirst: vi.fn(async ({ where }: { where: { id: keyof typeof people } }) =>
          profile(where.id),
        ),
        findMany: vi.fn().mockResolvedValue([
          profile('dp-khalid', {
            id: 'bus1',
            plateNumber: 'KKU-1001',
            name: null,
            isActive: true,
            route: { isActive: true },
          }),
          // Omar runs his own bus's route every day.
          profile('dp-omar', {
            id: 'bus2',
            plateNumber: 'KKU-1002',
            name: null,
            isActive: true,
            route: { isActive: true },
          }),
          profile('dp-saad'),
        ]),
        findUnique: vi.fn().mockResolvedValue({ userId: 'u-saad' }),
      },
      driverAssignment: { findFirst: vi.fn().mockResolvedValue({ driverProfileId: 'dp-khalid' }) },
      driverAbsence: {
        findFirst: vi.fn().mockResolvedValue(absence),
        findMany: vi.fn().mockResolvedValue([
          {
            driverProfileId: 'dp-khalid',
            coverDriverProfileId: absence?.coverDriverProfileId ?? null,
            busId: 'bus1',
          },
          ...otherAbsences,
        ]),
        update: vi.fn().mockReturnValue('update'),
      },
      dailyTrip: { findMany: vi.fn().mockResolvedValue([]) },
      auditLog: { create: vi.fn().mockReturnValue('audit') },
      $transaction: vi.fn().mockResolvedValue([]),
    };
    return { prisma: prisma as unknown as PrismaClient, raw: prisma };
  }

  const away = {
    id: 'abs1',
    coverDriverProfileId: null,
    driverProfile: { user: { id: 'u-khalid', firstName: 'Khalid', lastName: 'Ali' } },
  };

  it("sets the cover on the driver's report and tells both", async () => {
    const { prisma, raw } = planPrisma(away);
    const { service, send } = notifications();

    const result = await new CoverService(prisma, service).cover(
      'tenant1',
      'u-sup',
      'bus1',
      'dp-saad',
      tomorrow,
    );

    expect(result).toEqual({ trips: 0, planned: true });
    expect(raw.driverAbsence.update).toHaveBeenCalledWith({
      where: { id: 'abs1' },
      data: { coverDriverProfileId: 'dp-saad' },
    });
    expect(send).toHaveBeenCalledWith(
      'u-saad',
      expect.objectContaining({
        title: 'كُلّفت بتغطية رحلات الغد',
        body: 'رحلتا الذهاب والعودة على KKU-1001 بدلاً من Khalid Ali.',
      }),
    );
    expect(send).toHaveBeenCalledWith(
      'u-khalid',
      expect.objectContaining({ title: 'سائق بديل لرحلاتك غداً' }),
    );
  });

  it('marks drivers who run their own route that day as busy, and refuses them', async () => {
    const { prisma } = planPrisma(away);
    const covers = new CoverService(prisma, notifications().service);

    const candidates = await covers.candidates('tenant1', 'u-sup', 'bus1', tomorrow);
    const byId = Object.fromEntries(candidates.map((c) => [c.profileId, c]));
    expect(byId['dp-khalid']).toMatchObject({ regular: true, absent: true });
    expect(byId['dp-omar'].busy).toEqual(['OUTBOUND', 'RETURN']);
    expect(byId['dp-saad']).toMatchObject({ busy: [], absent: false });

    await expect(
      covers.cover('tenant1', 'u-sup', 'bus1', 'dp-omar', tomorrow),
    ).rejects.toMatchObject({
      code: 'DRIVER_BUSY',
    });
  });

  it('needs the driver to have reported the day first', async () => {
    const { prisma } = planPrisma(null);
    await expect(
      new CoverService(prisma, notifications().service).cover(
        't',
        'u-sup',
        'bus1',
        'dp-saad',
        tomorrow,
      ),
    ).rejects.toMatchObject({ code: 'NO_ABSENCE' });
  });
});

describe('holidays and the trip time', () => {
  it('keeps a holiday between one and 120 days, ending after it starts', async () => {
    const create = vi.fn(async ({ data }) => ({ id: 'h1', ...data }));
    const holidays = new HolidayService({
      holiday: { create },
      auditLog: { create: vi.fn() },
    } as unknown as PrismaClient);

    const holiday = await holidays.create('t', 'admin', {
      name: 'إجازة منتصف الفصل',
      startDate: new Date('2026-11-15T00:00:00Z'),
      endDate: new Date('2026-11-19T00:00:00Z'),
    });
    expect(holiday).toEqual({
      id: 'h1',
      name: 'إجازة منتصف الفصل',
      startDate: '2026-11-15',
      endDate: '2026-11-19',
      days: 5,
    });
    await expect(
      holidays.create('t', 'admin', {
        name: 'x',
        startDate: new Date('2026-11-19T00:00:00Z'),
        endDate: new Date('2026-11-15T00:00:00Z'),
      }),
    ).rejects.toMatchObject({ code: 'INVALID_RANGE' });
  });

  it('stores the trip time as minutes after midnight', async () => {
    const update = vi.fn().mockReturnValue('update');
    const admin = new AdminService({
      tenant: {
        update,
        findUniqueOrThrow: vi.fn().mockResolvedValue({ autoTrips: true, autoTripMinute: 405 }),
      },
      auditLog: { create: vi.fn().mockReturnValue('audit') },
      $transaction: vi.fn().mockResolvedValue([]),
    } as unknown as PrismaClient);

    const settings = await admin.updateSettings('t', 'admin', { autoTripTime: '06:45' });

    expect(update.mock.calls[0][0].data).toEqual({ autoTripMinute: 405 });
    expect(settings).toEqual({ autoTrips: true, autoTripTime: '06:45' });
  });
});

describe('a route a driver builds', () => {
  it("becomes the bus's fixed route, and admins are asked to add students", async () => {
    const prisma = {
      driverProfile: {
        findFirst: vi.fn().mockResolvedValue({
          id: 'dp-omar',
          user: { firstName: 'Omar', lastName: 'Salem' },
          driverAssignments: [
            { bus: { id: 'bus2', plateNumber: 'KKU-1002', name: null, route: null } },
          ],
        }),
      },
      bus: { update: vi.fn() },
      auditLog: { create: vi.fn() },
      user: { findMany: vi.fn().mockResolvedValue([{ id: 'u-admin' }]) },
    };
    const structure = { createRoute: vi.fn().mockResolvedValue({ id: 'r9', name: 'مسار عمر' }) };
    const { service, send } = notifications();

    await new DriverRouteService(
      prisma as unknown as PrismaClient,
      structure as unknown as StructureService,
      service,
    ).create('tenant1', 'u-omar', { name: 'مسار عمر', stopIds: ['n1', 'n2'] });

    expect(structure.createRoute).toHaveBeenCalledWith('tenant1', {
      name: 'مسار عمر',
      stopIds: ['n1', 'n2'],
    });
    expect(prisma.bus.update).toHaveBeenCalledWith({
      where: { id: 'bus2' },
      data: { routeId: 'r9' },
    });
    expect(send).toHaveBeenCalledWith('u-admin', {
      type: 'ROUTE_BY_DRIVER',
      title: 'مسار جديد من سائق',
      body: 'أنشأ Omar Salem «مسار عمر» لحافلة KKU-1002. أضف إليه الطالبات.',
    });
  });

  it('is built once; after that it is edited', async () => {
    const prisma = {
      driverProfile: {
        findFirst: vi.fn().mockResolvedValue({
          id: 'dp-omar',
          user: { firstName: 'Omar', lastName: 'Salem' },
          driverAssignments: [
            {
              bus: {
                id: 'bus2',
                plateNumber: 'KKU-1002',
                name: null,
                route: { id: 'r9', isActive: true },
              },
            },
          ],
        }),
      },
      auditLog: { create: vi.fn() },
    };
    const structure = {
      createRoute: vi.fn(),
      updateRoute: vi.fn().mockResolvedValue({ id: 'r9' }),
    };
    const routes = new DriverRouteService(
      prisma as unknown as PrismaClient,
      structure as unknown as StructureService,
      notifications().service,
    );

    await expect(routes.create('t', 'u', { name: 'x', stopIds: ['n1'] })).rejects.toMatchObject({
      code: 'ROUTE_EXISTS',
    });
    await routes.update('t', 'u', { stopIds: ['n2', 'n1'] });
    expect(structure.updateRoute).toHaveBeenCalledWith('t', 'r9', { stopIds: ['n2', 'n1'] });
  });
});
