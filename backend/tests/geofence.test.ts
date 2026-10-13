import { describe, it, expect, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { haversineDistanceMeters, isWithinGeofence } from '../src/utils/geofence';
import { LocationService } from '../src/modules/tracking/location.service';

function prisma(partial: unknown): PrismaClient {
  return partial as PrismaClient;
}

describe('geofence (Haversine)', () => {
  it('returns 0 distance for the same point', () => {
    const p = { latitude: 24.71, longitude: 46.62 };
    expect(haversineDistanceMeters(p, p)).toBe(0);
  });

  it('is approximately 111km for one degree of latitude', () => {
    const a = { latitude: 0, longitude: 0 };
    const b = { latitude: 1, longitude: 0 };
    const d = haversineDistanceMeters(a, b);
    expect(d).toBeGreaterThan(110_000);
    expect(d).toBeLessThan(112_000);
  });

  it('detects a point inside the geofence', () => {
    const center = { latitude: 24.71, longitude: 46.62 };
    expect(isWithinGeofence({ latitude: 24.711, longitude: 46.62 }, center, 200)).toBe(true);
    expect(isWithinGeofence({ latitude: 24.75, longitude: 46.62 }, center, 200)).toBe(false);
  });
});

describe('location service', () => {
  it('scopes active-trip lookup to today and chooses the most recently started trip', async () => {
    const findTrip = vi.fn().mockResolvedValue(null);
    const service = new LocationService(
      prisma({
        driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
        dailyTrip: { findFirst: findTrip },
      }),
      { completeTripByGeofence: vi.fn() } as never,
    );

    await expect(service.processLocation('t1', 'u1', 24.71, 46.62)).rejects.toThrow(
      'No active trip',
    );
    expect(findTrip).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: 't1',
          driverProfileId: 'dp1',
          status: 'IN_PROGRESS',
          tripDate: expect.any(Date),
        }),
        orderBy: { startedAt: 'desc' },
      }),
    );
  });

  it('rejects a location update with no active trip', async () => {
    const service = new LocationService(
      prisma({
        driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
        dailyTrip: { findFirst: vi.fn().mockResolvedValue(null) },
      }),
      { completeTripByGeofence: vi.fn() } as never,
    );
    await expect(service.processLocation('t1', 'u1', 24.71, 46.62)).rejects.toThrow(
      'No active trip',
    );
  });

  it('auto-completes after two arrival samples within the branch geofence', async () => {
    const branch = { latitude: 24.71, longitude: 46.62, radius: 200 };
    const trip = { id: 'trip1', busId: 'bus1', route: { branch } };
    const complete = vi.fn().mockResolvedValue(true);
    const service = new LocationService(
      prisma({
        driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
        dailyTrip: { findFirst: vi.fn().mockResolvedValue(trip) },
      }),
      { completeTripByGeofence: complete } as never,
      { minBroadcastIntervalMs: 0, arrivalSampleGapMs: 0 },
    );

    await service.processLocation('t1', 'u1', 24.71, 46.62);
    const second = await service.processLocation('t1', 'u1', 24.71, 46.62);
    expect(second.autoCompleted).toBe(true);
    expect(complete).toHaveBeenCalledWith('t1', 'trip1');
  });

  it('does not auto-complete when outside the geofence', async () => {
    const branch = { latitude: 24.71, longitude: 46.62, radius: 50 };
    const trip = { id: 'trip1', busId: 'bus1', route: { branch } };
    const complete = vi.fn();
    const service = new LocationService(
      prisma({
        driverProfile: { findFirst: vi.fn().mockResolvedValue({ id: 'dp1' }) },
        dailyTrip: { findFirst: vi.fn().mockResolvedValue(trip) },
      }),
      { completeTripByGeofence: complete } as never,
      { minBroadcastIntervalMs: 0, arrivalSampleGapMs: 0 },
    );

    await service.processLocation('t1', 'u1', 25.0, 47.0);
    await service.processLocation('t1', 'u1', 25.0, 47.0);
    expect(complete).not.toHaveBeenCalled();
  });
});
