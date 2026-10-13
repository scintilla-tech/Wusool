import { describe, expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { StudentTripService } from '../src/modules/trips/student-trip.service';
import { TripService } from '../src/modules/trips/trips.service';
import { TripEventBus } from '../src/modules/trips/trip-events';

describe('trip privacy and lifecycle events', () => {
  it('requires explicit trip membership before exposing a student trip or location', async () => {
    const findFirst = vi.fn().mockResolvedValue(null);
    const prisma = {
      studentProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'student-1' }) },
      studentAssignment: { findFirst: vi.fn().mockResolvedValue({ routeId: 'route-1' }) },
      dailyTrip: { findFirst },
    } as unknown as PrismaClient;
    const locationService = { getLatest: vi.fn() };
    const service = new StudentTripService(prisma, locationService as never);

    await expect(service.getTodayTrip('tenant-1', 'user-1')).resolves.toEqual({
      trip: null,
      myStatus: null,
      latestLocation: null,
    });
    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tripStudents: {
            some: { tenantId: 'tenant-1', studentProfileId: 'student-1' },
          },
        }),
      }),
    );
    expect(locationService.getLatest).not.toHaveBeenCalled();
  });

  it('emits the shared completion event after manual completion commits', async () => {
    const tx = {
      dailyTrip: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      tripStudent: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      auditLog: { create: vi.fn().mockResolvedValue({}) },
    };
    const prisma = {
      driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'driver-1' }) },
      dailyTrip: {
        findFirst: vi.fn().mockResolvedValue({
          id: 'trip-1',
          driverProfileId: 'driver-1',
          status: 'IN_PROGRESS',
        }),
        findUnique: vi.fn().mockResolvedValue({ id: 'trip-1', status: 'COMPLETED' }),
      },
      $transaction: vi.fn(async (callback: (client: typeof tx) => unknown) => callback(tx)),
    } as unknown as PrismaClient;
    const events = new TripEventBus();
    const completed = vi.fn();
    events.onCompleted(completed);

    await new TripService(prisma, events).completeTrip('tenant-1', 'driver-user', 'trip-1');

    expect(completed).toHaveBeenCalledWith({ tenantId: 'tenant-1', tripId: 'trip-1' });
  });
});
