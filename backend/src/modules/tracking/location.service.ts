import type { PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { isWithinGeofence } from '../../utils/geofence';
import { TripService } from '../trips/trips.service';

const MIN_BROADCAST_INTERVAL_MS = 2.5 * 60 * 1000; // ~2.5 min throttle toward the ~3 min target
const ARRIVAL_SAMPLE_GAP_MS = 30 * 1000; // 2 samples at least 30s apart
const ARRIVAL_SAMPLES_REQUIRED = 2;

export interface LocationResult {
  tripId: string;
  busId: string | null;
  latitude: number;
  longitude: number;
  broadcast: boolean;
  autoCompleted: boolean;
}

export interface LatestLocation {
  latitude: number;
  longitude: number;
  at: number;
}

/**
 * Validates, throttles, and processes driver location updates during ACTIVE trips.
 * Handles in-memory arrival sampling for geofence auto-completion.
 */
export class LocationService {
  private readonly lastBroadcast = new Map<string, number>();
  private readonly arrivalSamples = new Map<string, { firstAt: number; count: number }>();
  private readonly latestByTrip = new Map<string, LatestLocation>();
  private readonly minBroadcastIntervalMs: number;
  private readonly arrivalSampleGapMs: number;

  constructor(
    private readonly prisma: PrismaClient,
    private readonly tripService: TripService,
    options?: { minBroadcastIntervalMs?: number; arrivalSampleGapMs?: number },
  ) {
    this.minBroadcastIntervalMs = options?.minBroadcastIntervalMs ?? MIN_BROADCAST_INTERVAL_MS;
    this.arrivalSampleGapMs = options?.arrivalSampleGapMs ?? ARRIVAL_SAMPLE_GAP_MS;
  }

  /** Latest known location for an ACTIVE trip (transient, in-memory). */
  getLatest(tripId: string): LatestLocation | null {
    return this.latestByTrip.get(tripId) ?? null;
  }

  async processLocation(
    tenantId: string,
    driverUserId: string,
    latitude: number,
    longitude: number,
  ): Promise<LocationResult> {
    const profile = await this.prisma.driverProfile.findFirst({
      where: { userId: driverUserId, tenantId, isActive: true },
    });
    if (!profile) throw new AppError(404, 'NOT_FOUND', 'Driver profile not found');

    const trip = await this.prisma.dailyTrip.findFirst({
      where: { tenantId, driverProfileId: profile.id, status: 'IN_PROGRESS' },
      include: { route: { include: { branch: true } } },
    });
    if (!trip) throw new AppError(409, 'NO_ACTIVE_TRIP', 'No active trip');

    const now = Date.now();
    const last = this.lastBroadcast.get(driverUserId) ?? 0;
    const broadcast = now - last >= this.minBroadcastIntervalMs;
    if (broadcast) {
      this.lastBroadcast.set(driverUserId, now);
      this.latestByTrip.set(trip.id, { latitude, longitude, at: now });
    }

    let autoCompleted = false;
    const branch = trip.route?.branch ?? null;
    if (branch && branch.latitude != null && branch.longitude != null && branch.radius != null) {
      const inside = isWithinGeofence(
        { latitude, longitude },
        { latitude: branch.latitude, longitude: branch.longitude },
        branch.radius,
      );
      if (inside) {
        const s = this.arrivalSamples.get(trip.id) ?? { firstAt: now, count: 0 };
        s.count += 1;
        this.arrivalSamples.set(trip.id, s);
        if (s.count >= ARRIVAL_SAMPLES_REQUIRED && now - s.firstAt >= this.arrivalSampleGapMs) {
          this.arrivalSamples.delete(trip.id);
          autoCompleted = await this.tripService.completeTripByGeofence(tenantId, trip.id);
          if (autoCompleted) {
            // Privacy: stop exposing location once the trip is complete.
            this.latestByTrip.delete(trip.id);
          }
        }
      } else {
        this.arrivalSamples.delete(trip.id);
      }
    }

    return { tripId: trip.id, busId: trip.busId, latitude, longitude, broadcast, autoCompleted };
  }
}
