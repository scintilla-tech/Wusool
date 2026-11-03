import { Prisma, type PrismaClient, type TripDirection } from '@prisma/client';
import type { Logger } from 'pino';
import { businessDateParts, dateOnly } from '../../utils/date';
import { AppError } from '../../utils/appError';
import type { NotificationService } from '../notifications/notification.service';
import {
  coverAssigned,
  coverStillNeeded,
  tripNeeded,
  tripsReady,
} from '../notifications/trip-messages';
import type { TripService } from './trips.service';

/** Trips are created at each university's chosen time (05:30 by default)... */
export const DEFAULT_AUTO_TRIP_MINUTE = 5 * 60 + 30;

/** ...on school days, Sunday to Thursday (0 = Sunday), outside holidays. */
export const SCHOOL_DAYS = new Set([0, 1, 2, 3, 4]);

const DIRECTIONS: TripDirection[] = ['OUTBOUND', 'RETURN'];

export interface DayResult {
  trips: number;
  reminders: number;
}

/**
 * The morning schedule: on each school day that is not a holiday, every bus in
 * service with a driver and a fixed route gets its going and return trips, and
 * the driver is told. When the driver reported a day off, the cover the
 * supervisor picked gets the trips; with no cover yet, the supervisors are
 * reminded. A driver whose bus has no fixed route is reminded to build it.
 */
export class TripScheduleService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly trips: TripService,
    private readonly notifications: NotificationService,
    private readonly logger?: Logger,
  ) {}

  /** Checks every minute; each tenant's day runs once, whichever server gets it. */
  start(intervalMs = 60_000): () => void {
    const run = () => {
      this.tick().catch((error: unknown) =>
        this.logger?.error({ err: error }, 'Automatic trips failed'),
      );
    };
    run();
    const timer = setInterval(run, intervalMs);
    timer.unref();
    return () => clearInterval(timer);
  }

  async tick(now = new Date()): Promise<void> {
    const { hour, minute } = businessDateParts(now);
    const minuteOfDay = hour * 60 + minute;
    const day = dateOnly(now);
    if (!SCHOOL_DAYS.has(day.getUTCDay())) return;

    const tenants = await this.prisma.tenant.findMany({
      where: {
        isActive: true,
        autoTrips: true,
        autoTripMinute: { lte: minuteOfDay },
        autoTripRuns: { none: { tripDate: day } },
        holidays: { none: { startDate: { lte: day }, endDate: { gte: day } } },
      },
      select: { id: true },
    });
    for (const tenant of tenants) {
      const result = await this.runDay(tenant.id, day);
      if (result) this.logger?.info({ tenantId: tenant.id, ...result }, 'Automatic trips created');
    }
  }

  /** Returns null when the day was already run for the tenant. */
  async runDay(tenantId: string, day: Date): Promise<DayResult | null> {
    try {
      await this.prisma.autoTripRun.create({ data: { tenantId, tripDate: day } });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return null;
      }
      throw error;
    }

    const [buses, absences] = await Promise.all([
      this.prisma.bus.findMany({
        where: { tenantId, isActive: true },
        select: {
          id: true,
          plateNumber: true,
          name: true,
          route: { select: { id: true, name: true, isActive: true } },
          driverAssignments: {
            where: {
              isActive: true,
              driverProfile: { isActive: true, user: { isActive: true } },
            },
            orderBy: { assignedAt: 'desc' },
            take: 1,
            select: {
              driverProfile: {
                select: {
                  id: true,
                  userId: true,
                  user: { select: { firstName: true, lastName: true } },
                },
              },
            },
          },
          supervisorBusAssignments: {
            where: { isActive: true, supervisorProfile: { isActive: true } },
            select: { supervisorProfile: { select: { userId: true } } },
          },
        },
      }),
      this.prisma.driverAbsence.findMany({
        where: { tenantId, date: day },
        select: {
          driverProfileId: true,
          coverDriverProfile: {
            select: {
              id: true,
              userId: true,
              isActive: true,
              user: { select: { isActive: true } },
            },
          },
        },
      }),
    ]);
    const absenceOf = new Map(absences.map((a) => [a.driverProfileId, a]));

    const result: DayResult = { trips: 0, reminders: 0 };
    for (const bus of buses) {
      const driver = bus.driverAssignments[0]?.driverProfile;
      if (!driver) continue;
      const absence = absenceOf.get(driver.id);
      if (!bus.route?.isActive) {
        if (absence) continue;
        await this.notifications.send(driver.userId, tripNeeded(bus));
        result.reminders += 1;
        continue;
      }
      const cover = absence?.coverDriverProfile;
      const coverReady = cover?.isActive === true && cover.user.isActive;
      const made = await this.createBusTrips(
        tenantId,
        day,
        bus.id,
        bus.route.id,
        coverReady ? cover.id : driver.id,
        coverReady ? driver.id : undefined,
      );
      result.trips += made.length;
      if (made.length === 0) continue;
      const regularName = `${driver.user.firstName} ${driver.user.lastName}`;
      if (coverReady) {
        await this.notifications.send(cover.userId, coverAssigned(bus, regularName, made));
      } else if (absence) {
        // The driver is away and nobody covers yet: the supervisors still can today.
        await this.notifications.sendToAll(
          bus.supervisorBusAssignments.map((a) => a.supervisorProfile.userId),
          coverStillNeeded(regularName, bus),
        );
      } else {
        await this.notifications.send(driver.userId, tripsReady(bus, bus.route.name, made));
      }
    }

    await this.prisma.autoTripRun.update({
      where: { tenantId_tripDate: { tenantId, tripDate: day } },
      data: result,
    });
    await this.prisma.auditLog.create({
      data: {
        tenantId,
        action: 'TRIPS_AUTO_CREATED',
        entityType: 'DailyTrip',
        metadata: { tripDate: day.toISOString().slice(0, 10), ...result },
      },
    });
    return result;
  }

  /** Creates the bus's trips that do not exist yet; a refused one is skipped. */
  private async createBusTrips(
    tenantId: string,
    day: Date,
    busId: string,
    routeId: string,
    driverProfileId: string,
    coverFor?: string,
  ): Promise<TripDirection[]> {
    const existing = await this.prisma.dailyTrip.findMany({
      where: { tenantId, busId, tripDate: day, status: { not: 'CANCELLED' } },
      select: { direction: true },
    });
    const have = new Set(existing.map((trip) => trip.direction));
    const made: TripDirection[] = [];
    for (const direction of DIRECTIONS) {
      if (have.has(direction)) continue;
      try {
        await this.trips.createTrip(
          tenantId,
          { routeId, busId, driverProfileId, tripDate: day, direction },
          { origin: 'AUTOMATIC', ...(coverFor ? { coverFor } : {}) },
        );
        made.push(direction);
      } catch (error) {
        // The driver may be on another trip, or the route may already run:
        // the driver can still create the trip, so skip it and go on.
        if (!(error instanceof AppError)) throw error;
        this.logger?.warn(
          { tenantId, busId, direction, code: error.code },
          'Automatic trip skipped',
        );
      }
    }
    return made;
  }
}
