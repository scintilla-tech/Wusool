import { describe, it, expect, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { TripService } from '../src/modules/trips/trips.service';

function prisma(partial: unknown): PrismaClient {
  return partial as PrismaClient;
}

describe('trip completion + transport confirmation', () => {
  it('confirms only BOARDED students (never ATTENDING-only)', async () => {
    const updateMany = vi.fn().mockResolvedValue({ count: 2 });
    const tx = { dailyTrip: { update: vi.fn() }, tripStudent: { updateMany } };
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
        auditLog: { create: vi.fn() },
        $transaction: vi.fn(async (fn: (c: unknown) => unknown) => fn(tx)),
      }),
    );

    await service.completeTrip('t1', 'u1', 't1');
    expect(updateMany).toHaveBeenCalledWith({
      where: { dailyTripId: 't1', status: 'BOARDED' },
      data: { transportConfirmed: true },
    });
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
});
