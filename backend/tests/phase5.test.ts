import { describe, it, expect, vi } from 'vitest';
import { Prisma, type PrismaClient } from '@prisma/client';
import { SupervisorService } from '../src/modules/supervisor/supervisor.service';
import { TripService } from '../src/modules/trips/trips.service';

function prisma(partial: unknown): PrismaClient {
  return partial as PrismaClient;
}

describe('trip completion + transport confirmation', () => {
  it('rejects starting a trip outside the current local date', async () => {
    const transaction = vi.fn();
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const service = new TripService(
      prisma({
        driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
        dailyTrip: {
          findFirst: vi.fn().mockResolvedValue({
            id: 'trip1',
            tenantId: 'tenant1',
            status: 'SCHEDULED',
            driverProfileId: 'dp1',
            tripDate: yesterday,
          }),
        },
        $transaction: transaction,
      }),
    );

    await expect(service.startTrip('tenant1', 'u1', 'trip1')).rejects.toThrow(
      "Only today's trip can be started",
    );
    expect(transaction).not.toHaveBeenCalled();
  });

  it('confirms only BOARDED students (never ATTENDING-only)', async () => {
    const updateMany = vi.fn().mockResolvedValue({ count: 2 });
    const tx = {
      dailyTrip: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      tripStudent: { updateMany },
      auditLog: { create: vi.fn() },
    };
    const service = new TripService(
      prisma({
        driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
        dailyTrip: {
          findFirst: vi.fn().mockResolvedValue({
            id: 't1',
            tenantId: 't1',
            status: 'IN_PROGRESS',
            driverProfileId: 'dp1',
          }),
          findUnique: vi.fn().mockResolvedValue({ id: 't1', status: 'COMPLETED' }),
        },
        $transaction: vi.fn(async (fn: (c: unknown) => unknown) => fn(tx)),
      }),
    );

    await service.completeTrip('t1', 'u1', 't1');
    expect(updateMany).toHaveBeenCalledWith({
      where: { dailyTripId: 't1', status: 'BOARDED' },
      data: { transportConfirmed: true },
    });
  });

  it('allows only one concurrent completion to change the trip', async () => {
    const tx = {
      dailyTrip: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      tripStudent: { updateMany: vi.fn() },
      auditLog: { create: vi.fn() },
    };
    const service = new TripService(
      prisma({
        driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
        dailyTrip: {
          findFirst: vi.fn().mockResolvedValue({
            id: 'trip1',
            tenantId: 'tenant1',
            status: 'IN_PROGRESS',
            driverProfileId: 'dp1',
          }),
        },
        $transaction: vi.fn(async (fn: (c: unknown) => unknown) => fn(tx)),
      }),
    );

    await expect(service.completeTrip('tenant1', 'u1', 'trip1')).rejects.toThrow('not in progress');
    expect(tx.tripStudent.updateMany).not.toHaveBeenCalled();
    expect(tx.auditLog.create).not.toHaveBeenCalled();
  });

  it('rejects trip creation when the driver is not assigned to the bus', async () => {
    const service = new TripService(
      prisma({
        route: { findFirst: vi.fn().mockResolvedValue({ id: 'route1' }) },
        bus: { findFirst: vi.fn().mockResolvedValue({ id: 'bus1' }) },
        driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'driver1' }) },
        driverAssignment: { findFirst: vi.fn().mockResolvedValue(null) },
      }),
    );

    await expect(
      service.createTrip('tenant1', {
        routeId: 'route1',
        busId: 'bus1',
        driverProfileId: 'driver1',
        tripDate: new Date(),
      }),
    ).rejects.toThrow('not actively assigned');
  });

  it('rejects completing a trip that is not in progress', async () => {
    const service = new TripService(
      prisma({
        driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
        dailyTrip: {
          findFirst: vi.fn().mockResolvedValue({
            id: 't1',
            tenantId: 't1',
            status: 'SCHEDULED',
            driverProfileId: 'dp1',
          }),
        },
      }),
    );
    await expect(service.completeTrip('t1', 'u1', 't1')).rejects.toThrow('not in progress');
  });

  describe('starting a trip while another one runs', () => {
    function startService(failure: Error) {
      return new TripService(
        prisma({
          driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
          dailyTrip: {
            findFirst: vi.fn().mockResolvedValue({
              id: 'return-trip',
              tenantId: 'tenant1',
              status: 'SCHEDULED',
              driverProfileId: 'dp1',
              tripDate: new Date(),
            }),
          },
          $transaction: vi.fn().mockRejectedValue(failure),
        }),
      );
    }

    it('turns the running-trip index violation into a clear error', async () => {
      const violation = new Prisma.PrismaClientKnownRequestError('unique', {
        code: 'P2002',
        clientVersion: 'test',
      });

      await expect(
        startService(violation).startTrip('tenant1', 'u1', 'return-trip'),
      ).rejects.toMatchObject({ statusCode: 409, code: 'TRIP_ALREADY_IN_PROGRESS' });
    });

    it('does not disguise other database failures', async () => {
      const failure = new Error('connection lost');

      await expect(startService(failure).startTrip('tenant1', 'u1', 'return-trip')).rejects.toBe(
        failure,
      );
    });
  });

  describe("driver's list of today's trips", () => {
    function listService() {
      const findMany = vi.fn().mockResolvedValue([{ id: 'outbound' }, { id: 'return' }]);
      const service = new TripService(
        prisma({
          driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
          dailyTrip: { findMany },
        }),
      );
      return { service, findMany };
    }

    it('includes finished trips so their summary stays reachable', async () => {
      const { service, findMany } = listService();

      await service.getDriverTodayTrips('tenant1', 'u1');
      expect(findMany.mock.calls[0][0].where.status.in).toEqual([
        'SCHEDULED',
        'IN_PROGRESS',
        'COMPLETED',
      ]);
    });

    it('keeps the single current trip limited to active trips', async () => {
      const { service, findMany } = listService();

      await service.getDriverToday('tenant1', 'u1');
      expect(findMany.mock.calls[0][0].where.status.in).toEqual(['SCHEDULED', 'IN_PROGRESS']);
    });
  });
});

describe('supervisor bus card', () => {
  const trip = (
    id: string,
    direction: 'OUTBOUND' | 'RETURN',
    status: string,
    completedAt: Date | null = null,
  ) => ({
    id,
    direction,
    status,
    completedAt,
    busId: 'bus1',
    route: { name: 'North Loop' },
    tripStudents: [{ status: id === 'return' ? 'BOARDED' : 'WAITING' }],
    attendanceSession: null,
  });

  async function cardFor(trips: ReturnType<typeof trip>[]) {
    const service = new SupervisorService(
      prisma({
        supervisorProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'sp1' }) },
        supervisorBusAssignment: {
          findMany: vi
            .fn()
            .mockResolvedValue([{ bus: { id: 'bus1', plateNumber: 'KKU-1003', name: null } }]),
        },
        dailyTrip: { findMany: vi.fn().mockResolvedValue(trips) },
      }),
    );
    const [card] = await service.getMyBuses('tenant1', 'u1', 'SUPERVISOR');
    return card;
  }

  it('follows the return trip while it is running', async () => {
    const card = await cardFor([
      trip('outbound', 'OUTBOUND', 'COMPLETED', new Date('2026-11-02T05:00:00Z')),
      trip('return', 'RETURN', 'IN_PROGRESS'),
    ]);

    expect(card.trip).toMatchObject({ id: 'return', direction: 'RETURN' });
    expect(card.counts.boarded).toBe(1);
  });

  it('keeps showing the finished outbound trip until the return trip starts', async () => {
    const card = await cardFor([
      trip('outbound', 'OUTBOUND', 'COMPLETED', new Date('2026-11-02T05:00:00Z')),
      trip('return', 'RETURN', 'SCHEDULED'),
    ]);

    expect(card.trip).toMatchObject({ id: 'outbound', status: 'COMPLETED' });
  });

  it('shows the trip that finished last once both are done', async () => {
    const card = await cardFor([
      trip('outbound', 'OUTBOUND', 'COMPLETED', new Date('2026-11-02T05:00:00Z')),
      trip('return', 'RETURN', 'COMPLETED', new Date('2026-11-02T13:00:00Z')),
    ]);

    expect(card.trip?.id).toBe('return');
  });

  it('starts the day on the scheduled outbound trip', async () => {
    const card = await cardFor([
      trip('return', 'RETURN', 'SCHEDULED'),
      trip('outbound', 'OUTBOUND', 'SCHEDULED'),
    ]);

    expect(card.trip?.id).toBe('outbound');
  });
});
