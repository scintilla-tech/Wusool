import { describe, expect, it, vi } from 'vitest';
import { Prisma, type PrismaClient } from '@prisma/client';
import { TripScheduleService } from '../src/modules/trips/trip-schedule.service';
import { CoverService } from '../src/modules/supervisor/cover.service';
import { TripService } from '../src/modules/trips/trips.service';
import type { NotificationService } from '../src/modules/notifications/notification.service';
import { AppError } from '../src/utils/appError';

const MONDAY = new Date('2026-11-02T00:00:00Z');

function notifications() {
  const send = vi.fn().mockResolvedValue(undefined);
  const sendToAll = vi.fn(async (ids: string[], payload: unknown) => {
    for (const id of ids) await send(id, payload);
  });
  return { service: { send, sendToAll } as unknown as NotificationService, send };
}

const driver = (id: string) => ({
  driverProfile: {
    id: `dp-${id}`,
    userId: `u-${id}`,
    user: { firstName: id[0].toUpperCase() + id.slice(1), lastName: 'Driver' },
  },
});

describe('the morning schedule', () => {
  function schedulePrisma(
    buses: Record<string, unknown>[],
    existing: { direction: string }[] = [],
    absences: unknown[] = [],
  ) {
    const prisma = {
      autoTripRun: { create: vi.fn().mockResolvedValue({}), update: vi.fn() },
      bus: {
        findMany: vi
          .fn()
          .mockResolvedValue(buses.map((bus) => ({ supervisorBusAssignments: [], ...bus }))),
      },
      dailyTrip: { findMany: vi.fn().mockResolvedValue(existing) },
      driverAbsence: { findMany: vi.fn().mockResolvedValue(absences) },
      auditLog: { create: vi.fn() },
      tenant: { findMany: vi.fn().mockResolvedValue([{ id: 'tenant1' }]) },
    };
    return { prisma: prisma as unknown as PrismaClient, raw: prisma };
  }

  it('makes both trips for a bus with a fixed route and tells its driver', async () => {
    const { prisma, raw } = schedulePrisma([
      {
        id: 'bus1',
        plateNumber: 'KKU-1001',
        name: null,
        route: { id: 'r1', name: 'North Loop', isActive: true },
        driverAssignments: [driver('khalid')],
      },
    ]);
    const createTrip = vi.fn().mockResolvedValue({});
    const { service, send } = notifications();

    const result = await new TripScheduleService(
      prisma,
      { createTrip } as unknown as TripService,
      service,
    ).runDay('tenant1', MONDAY);

    expect(result).toEqual({ trips: 2, reminders: 0 });
    expect(createTrip.mock.calls.map((call) => call[1].direction)).toEqual(['OUTBOUND', 'RETURN']);
    expect(createTrip.mock.calls[0]).toEqual([
      'tenant1',
      {
        routeId: 'r1',
        busId: 'bus1',
        driverProfileId: 'dp-khalid',
        tripDate: MONDAY,
        direction: 'OUTBOUND',
      },
      { origin: 'AUTOMATIC' },
    ]);
    expect(send).toHaveBeenCalledWith('u-khalid', {
      type: 'TRIPS_READY',
      title: 'رحلات اليوم جاهزة',
      body: 'رحلتا الذهاب والعودة على KKU-1001 · North Loop.',
      data: { directions: ['OUTBOUND', 'RETURN'] },
    });
    expect(raw.autoTripRun.update.mock.calls[0][0].data).toEqual({ trips: 2, reminders: 0 });
  });

  it('reminds the driver of a bus without a fixed route, and skips a bus with no driver', async () => {
    const { prisma } = schedulePrisma([
      {
        id: 'bus2',
        plateNumber: 'KKU-1002',
        name: 'حافلة 2',
        route: null,
        driverAssignments: [driver('omar')],
      },
      {
        id: 'bus4',
        plateNumber: 'KKU-1004',
        name: null,
        route: { id: 'r2', name: 'East', isActive: true },
        driverAssignments: [],
      },
    ]);
    const createTrip = vi.fn();
    const { service, send } = notifications();

    const result = await new TripScheduleService(
      prisma,
      { createTrip } as unknown as TripService,
      service,
    ).runDay('tenant1', MONDAY);

    expect(result).toEqual({ trips: 0, reminders: 1 });
    expect(createTrip).not.toHaveBeenCalled();
    expect(send).toHaveBeenCalledWith(
      'u-omar',
      expect.objectContaining({
        type: 'TRIP_NEEDED',
        body: 'ليس لـحافلة 2 مسار ثابت. أنشئ مسارها من التطبيق مرة واحدة لتُجدول رحلاتها.',
      }),
    );
  });

  it('keeps trips that exist and skips one it is refused, without failing the day', async () => {
    const { prisma } = schedulePrisma(
      [
        {
          id: 'bus1',
          plateNumber: 'KKU-1001',
          name: null,
          route: { id: 'r1', name: 'North Loop', isActive: true },
          driverAssignments: [driver('khalid')],
        },
      ],
      [{ direction: 'OUTBOUND' }],
    );
    const createTrip = vi.fn().mockRejectedValue(new AppError(409, 'TRIP_CONFLICT', 'busy'));
    const { service, send } = notifications();

    const result = await new TripScheduleService(
      prisma,
      { createTrip } as unknown as TripService,
      service,
    ).runDay('tenant1', MONDAY);

    expect(createTrip).toHaveBeenCalledTimes(1);
    expect(createTrip.mock.calls[0][1].direction).toBe('RETURN');
    expect(result).toEqual({ trips: 0, reminders: 0 });
    expect(send).not.toHaveBeenCalled();
  });

  it('runs a day once, even when two servers try', async () => {
    const { prisma, raw } = schedulePrisma([]);
    raw.autoTripRun.create.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('unique', { code: 'P2002', clientVersion: 'test' }),
    );

    const result = await new TripScheduleService(
      prisma,
      {} as TripService,
      notifications().service,
    ).runDay('tenant1', MONDAY);

    expect(result).toBeNull();
    expect(raw.bus.findMany).not.toHaveBeenCalled();
  });

  it("runs on school days at each university's time, outside holidays", async () => {
    const { prisma, raw } = schedulePrisma([]);
    const schedule = new TripScheduleService(prisma, {} as TripService, notifications().service);

    await schedule.tick(new Date('2026-11-06T06:00:00Z')); // Friday
    expect(raw.tenant.findMany).not.toHaveBeenCalled();

    await schedule.tick(new Date('2026-11-02T02:30:00Z')); // Monday 5:30 Riyadh
    expect(raw.tenant.findMany.mock.calls[0][0].where).toEqual({
      isActive: true,
      autoTrips: true,
      autoTripMinute: { lte: 330 },
      autoTripRuns: { none: { tripDate: MONDAY } },
      holidays: { none: { startDate: { lte: MONDAY }, endDate: { gte: MONDAY } } },
    });
    expect(raw.autoTripRun.create).toHaveBeenCalledWith({
      data: { tenantId: 'tenant1', tripDate: MONDAY },
    });
  });

  it("gives an away driver's trips to the cover the supervisor picked", async () => {
    const { prisma } = schedulePrisma(
      [
        {
          id: 'bus1',
          plateNumber: 'KKU-1001',
          name: null,
          route: { id: 'r1', name: 'North Loop', isActive: true },
          driverAssignments: [driver('khalid')],
        },
      ],
      [],
      [
        {
          driverProfileId: 'dp-khalid',
          coverDriverProfile: {
            id: 'dp-omar',
            userId: 'u-omar',
            isActive: true,
            user: { isActive: true },
          },
        },
      ],
    );
    const createTrip = vi.fn().mockResolvedValue({});
    const { service, send } = notifications();

    await new TripScheduleService(prisma, { createTrip } as unknown as TripService, service).runDay(
      'tenant1',
      MONDAY,
    );

    expect(createTrip.mock.calls[0][1].driverProfileId).toBe('dp-omar');
    expect(createTrip.mock.calls[0][2]).toEqual({ origin: 'AUTOMATIC', coverFor: 'dp-khalid' });
    expect(send).toHaveBeenCalledWith(
      'u-omar',
      expect.objectContaining({
        type: 'COVER_ASSIGNED',
        body: 'رحلتا الذهاب والعودة على KKU-1001 بدلاً من Khalid Driver.',
      }),
    );
    expect(send).not.toHaveBeenCalledWith('u-khalid', expect.anything());
  });

  it('reminds the supervisors when an away driver has no cover yet', async () => {
    const { prisma } = schedulePrisma(
      [
        {
          id: 'bus1',
          plateNumber: 'KKU-1001',
          name: null,
          route: { id: 'r1', name: 'North Loop', isActive: true },
          driverAssignments: [driver('khalid')],
          supervisorBusAssignments: [{ supervisorProfile: { userId: 'u-noura' } }],
        },
      ],
      [],
      [{ driverProfileId: 'dp-khalid', coverDriverProfile: null }],
    );
    const createTrip = vi.fn().mockResolvedValue({});
    const { service, send } = notifications();

    await new TripScheduleService(prisma, { createTrip } as unknown as TripService, service).runDay(
      'tenant1',
      MONDAY,
    );

    // Trips are still made, so the supervisor can give them to a cover today.
    expect(createTrip.mock.calls[0][1].driverProfileId).toBe('dp-khalid');
    expect(send).toHaveBeenCalledWith('u-noura', expect.objectContaining({ type: 'COVER_NEEDED' }));
    expect(send).not.toHaveBeenCalledWith('u-khalid', expect.anything());
  });
});

describe('cover drivers', () => {
  const omar = { id: 'dp-omar', user: { id: 'u-omar', firstName: 'Omar', lastName: 'Salem' } };
  const khalid = {
    id: 'dp-khalid',
    user: { id: 'u-khalid', firstName: 'Khalid', lastName: 'Ali' },
  };

  function coverPrisma(options: {
    trips: {
      id: string;
      direction: string;
      driverProfileId: string;
      coveredDriverProfileId: string | null;
    }[];
    clash?: boolean;
    regular?: string;
  }) {
    const tx = {
      dailyTrip: { updateMany: vi.fn() },
      auditLog: { create: vi.fn() },
      driverAbsence: { updateMany: vi.fn(), deleteMany: vi.fn() },
    };
    const prisma = {
      supervisorBusAssignment: {
        findFirst: vi
          .fn()
          .mockResolvedValue({ bus: { id: 'bus1', plateNumber: 'KKU-1001', name: null } }),
      },
      driverProfile: {
        findFirst: vi.fn(
          async ({ where }: { where: { id: string } }) =>
            [omar, khalid].find((d) => d.id === where.id) ?? null,
        ),
        findMany: vi.fn(async ({ where }: { where: { id: { in: string[] } } }) =>
          [omar, khalid].filter((d) => where.id.in.includes(d.id)),
        ),
      },
      dailyTrip: {
        findMany: vi.fn().mockResolvedValue(options.trips),
        findFirst: vi.fn().mockResolvedValue(options.clash ? { id: 'other' } : null),
      },
      driverAssignment: {
        findFirst: vi.fn().mockResolvedValue({ driverProfileId: options.regular ?? 'dp-khalid' }),
      },
      driverAbsence: { findFirst: vi.fn().mockResolvedValue(null) },
      $transaction: vi.fn(async (fn: (c: typeof tx) => unknown) => fn(tx)),
    };
    return { prisma: prisma as unknown as PrismaClient, raw: prisma, tx };
  }

  const scheduled = (direction: string, driverProfileId = 'dp-khalid') => ({
    id: `trip-${direction}`,
    direction,
    driverProfileId,
    coveredDriverProfileId: null,
  });

  it("moves the day's trips to the cover and tells both drivers", async () => {
    const { prisma, tx } = coverPrisma({ trips: [scheduled('OUTBOUND'), scheduled('RETURN')] });
    const { service, send } = notifications();

    const result = await new CoverService(prisma, service).cover(
      'tenant1',
      'u-sup',
      'bus1',
      'dp-omar',
    );

    expect(result).toEqual({ trips: 2, planned: false });
    expect(tx.dailyTrip.updateMany).toHaveBeenCalledWith({
      where: { id: 'trip-OUTBOUND', status: 'SCHEDULED' },
      data: { driverProfileId: 'dp-omar', coveredDriverProfileId: 'dp-khalid' },
    });
    expect(tx.auditLog.create.mock.calls[0][0].data).toMatchObject({
      action: 'TRIP_DRIVER_COVERED',
      actorUserId: 'u-sup',
    });
    expect(send).toHaveBeenCalledWith(
      'u-omar',
      expect.objectContaining({
        type: 'COVER_ASSIGNED',
        body: 'رحلتا الذهاب والعودة على KKU-1001 بدلاً من Khalid Ali.',
      }),
    );
    expect(send).toHaveBeenCalledWith(
      'u-khalid',
      expect.objectContaining({
        type: 'COVER_REPLACED',
        body: 'رحلتا الذهاب والعودة على KKU-1001 اليوم مع Omar Salem.',
      }),
    );
  });

  it('hands the trips back to the regular driver', async () => {
    const covered = { ...scheduled('RETURN', 'dp-omar'), coveredDriverProfileId: 'dp-khalid' };
    const { prisma, tx } = coverPrisma({ trips: [covered] });
    const { service, send } = notifications();

    await new CoverService(prisma, service).cover('tenant1', 'u-sup', 'bus1', 'dp-khalid');

    expect(tx.dailyTrip.updateMany.mock.calls[0][0].data).toEqual({
      driverProfileId: 'dp-khalid',
      coveredDriverProfileId: null,
    });
    expect(send).toHaveBeenCalledWith('u-khalid', expect.objectContaining({ type: 'COVER_ENDED' }));
    expect(send).toHaveBeenCalledWith(
      'u-omar',
      expect.objectContaining({ type: 'COVER_CANCELLED' }),
    );
  });

  it('tells the regular driver and the old cover when the cover changes', async () => {
    const majed = { id: 'dp-majed', user: { id: 'u-majed', firstName: 'Majed', lastName: 'Test' } };
    const covered = { ...scheduled('RETURN', 'dp-omar'), coveredDriverProfileId: 'dp-khalid' };
    const { prisma, raw, tx } = coverPrisma({ trips: [covered] });
    const drivers = [omar, khalid, majed];
    raw.driverProfile.findFirst.mockImplementation(
      async ({ where }: { where: { id: string } }) =>
        drivers.find((d) => d.id === where.id) ?? null,
    );
    raw.driverProfile.findMany.mockImplementation(
      async ({ where }: { where: { id: { in: string[] } } }) =>
        drivers.filter((d) => where.id.in.includes(d.id)),
    );
    const { service, send } = notifications();

    await new CoverService(prisma, service).cover('tenant1', 'u-sup', 'bus1', 'dp-majed');

    // Still Khalid's trip, now driven by Majed.
    expect(tx.dailyTrip.updateMany.mock.calls[0][0].data).toEqual({
      driverProfileId: 'dp-majed',
      coveredDriverProfileId: 'dp-khalid',
    });
    expect(send).toHaveBeenCalledWith(
      'u-majed',
      expect.objectContaining({ body: 'رحلة العودة على KKU-1001 بدلاً من Khalid Ali.' }),
    );
    expect(send).toHaveBeenCalledWith(
      'u-omar',
      expect.objectContaining({
        type: 'COVER_CANCELLED',
        body: 'رحلة العودة على KKU-1001 أُسندت إلى سائق آخر.',
      }),
    );
    expect(send).toHaveBeenCalledWith(
      'u-khalid',
      expect.objectContaining({
        type: 'COVER_REPLACED',
        body: 'رحلة العودة على KKU-1001 اليوم مع Majed Test.',
      }),
    );
  });

  it('refuses a driver busy on another bus at the same time', async () => {
    const { prisma, tx } = coverPrisma({ trips: [scheduled('OUTBOUND')], clash: true });

    await expect(
      new CoverService(prisma, notifications().service).cover(
        'tenant1',
        'u-sup',
        'bus1',
        'dp-omar',
      ),
    ).rejects.toMatchObject({ statusCode: 409, code: 'DRIVER_BUSY' });
    expect(tx.dailyTrip.updateMany).not.toHaveBeenCalled();
  });

  it('refuses when no trip is left to start', async () => {
    const { prisma } = coverPrisma({ trips: [] });

    await expect(
      new CoverService(prisma, notifications().service).cover(
        'tenant1',
        'u-sup',
        'bus1',
        'dp-omar',
      ),
    ).rejects.toMatchObject({ statusCode: 409, code: 'NO_TRIPS_TO_COVER' });
  });

  it("only works on the supervisor's own bus", async () => {
    const { prisma, raw } = coverPrisma({ trips: [] });
    raw.supervisorBusAssignment.findFirst.mockResolvedValue(null);

    await expect(
      new CoverService(prisma, notifications().service).candidates('tenant1', 'u-sup', 'bus9'),
    ).rejects.toMatchObject({ statusCode: 404 });
    expect(raw.supervisorBusAssignment.findFirst.mock.calls[0][0].where).toMatchObject({
      busId: 'bus9',
      supervisorProfile: { userId: 'u-sup', isActive: true },
    });
  });
});

describe('trips a driver creates', () => {
  function driverPrisma(options: {
    route?: { id: string; name: string } | null;
    existing?: boolean;
  }) {
    const prisma = {
      driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
      driverAssignment: {
        findFirst: vi.fn().mockResolvedValue({
          bus: {
            id: 'bus1',
            plateNumber: 'KKU-1002',
            name: null,
            route: options.route
              ? {
                  ...options.route,
                  code: null,
                  isActive: true,
                  branch: null,
                  routeNeighborhoods: [{ neighborhood: { id: 'n1', name: 'النرجس' } }],
                }
              : null,
          },
        }),
      },
      tenant: {
        findUniqueOrThrow: vi.fn().mockResolvedValue({ autoTrips: true, autoTripMinute: 390 }),
      },
      holiday: { findFirst: vi.fn().mockResolvedValue(null) },
      dailyTrip: {
        findMany: vi.fn().mockResolvedValue([]),
        findFirst: vi.fn().mockResolvedValue(options.existing ? { id: 'trip1' } : null),
      },
    };
    return { prisma: prisma as unknown as PrismaClient, raw: prisma };
  }

  it("shows the bus's fixed route with its stops and the university's trip time", async () => {
    const service = new TripService(
      driverPrisma({ route: { id: 'r1', name: 'North Loop' } }).prisma,
    );

    const bus = await service.getDriverBus('tenant1', 'u1');

    expect(bus).toMatchObject({
      autoTripTime: '06:30',
      holiday: null,
      route: { id: 'r1', stops: [{ id: 'n1', name: 'النرجس' }] },
    });
  });

  it('uses the fixed route of the bus', async () => {
    const { prisma } = driverPrisma({ route: { id: 'r1', name: 'North Loop' } });
    const service = new TripService(prisma);
    const createTrip = vi.spyOn(service, 'createTrip').mockResolvedValue({} as never);

    await service.createTripByDriver('tenant1', 'u1', { direction: 'RETURN' });

    expect(createTrip).toHaveBeenCalledWith(
      'tenant1',
      expect.objectContaining({
        routeId: 'r1',
        busId: 'bus1',
        driverProfileId: 'dp1',
        direction: 'RETURN',
      }),
      { origin: 'DRIVER', actorUserId: 'u1' },
    );
  });

  it('asks a driver to build the route before creating trips', async () => {
    const service = new TripService(driverPrisma({}).prisma);
    await expect(
      service.createTripByDriver('tenant1', 'u1', { direction: 'OUTBOUND' }),
    ).rejects.toMatchObject({ statusCode: 409, code: 'NO_ROUTE' });
  });

  it('refuses a second trip in the same direction', async () => {
    const service = new TripService(
      driverPrisma({ route: { id: 'r1', name: 'North Loop' }, existing: true }).prisma,
    );
    await expect(
      service.createTripByDriver('tenant1', 'u1', { direction: 'OUTBOUND' }),
    ).rejects.toMatchObject({ code: 'TRIP_EXISTS' });
  });

  it('refuses a trip on a route that already runs that day', async () => {
    const service = new TripService({
      route: { findFirst: vi.fn().mockResolvedValue({ id: 'r1' }) },
      bus: { findFirst: vi.fn().mockResolvedValue({ id: 'bus1' }) },
      driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
      driverAssignment: { findFirst: vi.fn().mockResolvedValue({ id: 'a1' }) },
      dailyTrip: { findFirst: vi.fn().mockResolvedValue({ id: 'other-bus-trip' }) },
    } as unknown as PrismaClient);

    await expect(
      service.createTrip('tenant1', {
        routeId: 'r1',
        busId: 'bus1',
        driverProfileId: 'dp1',
        tripDate: MONDAY,
        direction: 'OUTBOUND',
      }),
    ).rejects.toMatchObject({ statusCode: 409, code: 'ROUTE_TRIP_EXISTS' });
  });
});
