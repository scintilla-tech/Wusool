import type { PrismaClient, TripDirection } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { dateOnly } from '../../utils/date';
import type { NotificationService } from '../notifications/notification.service';
import {
  coverAssigned,
  coverCancelled,
  coverEnded,
  coverReplaced,
  dayPhrase,
} from '../notifications/trip-messages';

const BOTH: TripDirection[] = ['OUTBOUND', 'RETURN'];

const fullName = (user: { firstName: string; lastName: string }) =>
  `${user.firstName} ${user.lastName}`;

export interface CoverCandidate {
  id: string;
  profileId: string;
  firstName: string;
  lastName: string;
  phone: string;
  /** The bus the driver normally drives. */
  bus: { id: string; plateNumber: string; name: string | null } | null;
  /**
   * Directions in which the driver drives elsewhere that day: trips not
   * started or running today; on a coming day, their own bus's route or
   * another bus they cover.
   */
  busy: TripDirection[];
  /** Drives (or is set to drive) this bus's trips that day. */
  current: boolean;
  /** This bus's own driver. */
  regular: boolean;
  /** Reported they cannot drive that day. */
  absent: boolean;
}

/**
 * A bus supervisor puts another driver on today's trips of their bus when its
 * driver cannot make it. Both drivers are told.
 */
export class CoverService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly notifications: NotificationService,
  ) {}

  /** Drivers the supervisor can choose from for the bus's trips on `date` (today by default). */
  async candidates(
    tenantId: string,
    supervisorUserId: string,
    busId: string,
    date?: Date,
  ): Promise<CoverCandidate[]> {
    await this.assertSupervisesBus(tenantId, supervisorUserId, busId);
    const today = dateOnly(new Date());
    const day = date ? dateOnly(date) : today;
    const isToday = day.getTime() === today.getTime();
    const [drivers, trips, regular, absences] = await Promise.all([
      this.prisma.driverProfile.findMany({
        where: { tenantId, isActive: true, user: { isActive: true } },
        select: {
          id: true,
          user: { select: { id: true, firstName: true, lastName: true, phone: true } },
          driverAssignments: {
            where: { isActive: true },
            take: 1,
            select: {
              bus: {
                select: {
                  id: true,
                  plateNumber: true,
                  name: true,
                  isActive: true,
                  route: { select: { isActive: true } },
                },
              },
            },
          },
        },
        orderBy: { user: { firstName: 'asc' } },
        take: 200,
      }),
      isToday
        ? this.prisma.dailyTrip.findMany({
            where: { tenantId, tripDate: today, status: { in: ['SCHEDULED', 'IN_PROGRESS'] } },
            select: { busId: true, driverProfileId: true, direction: true },
          })
        : Promise.resolve([]),
      this.regularDriverId(tenantId, busId),
      this.prisma.driverAbsence.findMany({
        where: { tenantId, date: day },
        select: { driverProfileId: true, coverDriverProfileId: true, busId: true },
      }),
    ]);
    const absent = new Set(absences.map((a) => a.driverProfileId));

    return drivers.map((driver) => {
      const assigned = driver.driverAssignments[0]?.bus ?? null;
      let busy: TripDirection[];
      let current: boolean;
      if (isToday) {
        const own = trips.filter((trip) => trip.driverProfileId === driver.id);
        busy = own.filter((trip) => trip.busId !== busId).map((trip) => trip.direction);
        current = own.some((trip) => trip.busId === busId);
      } else {
        const drivesOwn =
          !absent.has(driver.id) &&
          assigned?.id !== busId &&
          assigned?.isActive === true &&
          assigned.route?.isActive === true;
        const coversOther = absences.some(
          (a) => a.coverDriverProfileId === driver.id && a.busId !== busId,
        );
        busy = drivesOwn || coversOther ? [...BOTH] : [];
        current = absences.some((a) => a.coverDriverProfileId === driver.id && a.busId === busId);
      }
      return {
        id: driver.user.id,
        profileId: driver.id,
        firstName: driver.user.firstName,
        lastName: driver.user.lastName,
        phone: driver.user.phone,
        bus: assigned
          ? { id: assigned.id, plateNumber: assigned.plateNumber, name: assigned.name }
          : null,
        busy,
        current,
        regular: driver.id === regular,
        absent: absent.has(driver.id),
      };
    });
  }

  /**
   * Today: gives the bus's trips that have not started to `driverProfileId`;
   * choosing the bus's own driver again hands them back. A coming day (or
   * today before its trips are made): sets the cover on the driver's
   * reported absence, and the day's trips are made with the cover.
   */
  async cover(
    tenantId: string,
    supervisorUserId: string,
    busId: string,
    driverProfileId: string,
    date?: Date,
  ): Promise<{ trips: number; planned: boolean }> {
    const bus = await this.assertSupervisesBus(tenantId, supervisorUserId, busId);
    const today = dateOnly(new Date());
    const day = date ? dateOnly(date) : today;
    if (day.getTime() < today.getTime()) {
      throw new AppError(422, 'INVALID_DATE', 'Covers are for today or a coming day');
    }
    const cover = await this.prisma.driverProfile.findFirst({
      where: { id: driverProfileId, tenantId, isActive: true, user: { isActive: true } },
      select: { id: true, user: { select: { id: true, firstName: true, lastName: true } } },
    });
    if (!cover) throw new AppError(404, 'NOT_FOUND', 'Driver not found or disabled');

    const trips =
      day.getTime() === today.getTime()
        ? await this.prisma.dailyTrip.findMany({
            where: { tenantId, busId, tripDate: today, status: 'SCHEDULED' },
            select: {
              id: true,
              direction: true,
              driverProfileId: true,
              coveredDriverProfileId: true,
            },
          })
        : [];
    if (trips.length === 0) {
      return this.plan(tenantId, supervisorUserId, bus, cover, day, today);
    }
    const coverAbsent = await this.prisma.driverAbsence.findFirst({
      where: { tenantId, driverProfileId: cover.id, date: today },
      select: { id: true },
    });
    if (coverAbsent) {
      throw new AppError(409, 'DRIVER_BUSY', 'The driver reported they cannot drive today');
    }
    const moving = trips.filter((trip) => trip.driverProfileId !== cover.id);
    if (moving.length === 0) {
      throw new AppError(409, 'NO_TRIPS_TO_COVER', 'The driver already drives these trips');
    }
    const directions = moving.map((trip) => trip.direction);
    const clash = await this.prisma.dailyTrip.findFirst({
      where: {
        tenantId,
        tripDate: today,
        driverProfileId: cover.id,
        busId: { not: busId },
        direction: { in: directions },
        status: { in: ['SCHEDULED', 'IN_PROGRESS'] },
      },
      select: { id: true },
    });
    if (clash) {
      throw new AppError(409, 'DRIVER_BUSY', 'The driver has another trip at the same time');
    }

    const regularId = await this.regularDriverId(tenantId, busId);
    const handedBack = cover.id === regularId;
    // Whoever drove the trips until now; usually the bus's own driver.
    const previousIds = [...new Set(moving.map((trip) => trip.driverProfileId))].filter(
      (id): id is string => id !== null,
    );

    await this.prisma.$transaction(async (tx) => {
      for (const trip of moving) {
        await tx.dailyTrip.updateMany({
          where: { id: trip.id, status: 'SCHEDULED' },
          data: {
            driverProfileId: cover.id,
            coveredDriverProfileId: handedBack
              ? null
              : (trip.coveredDriverProfileId ?? trip.driverProfileId),
          },
        });
      }
      await tx.auditLog.create({
        data: {
          tenantId,
          actorUserId: supervisorUserId,
          action: 'TRIP_DRIVER_COVERED',
          entityType: 'Bus',
          entityId: busId,
          metadata: {
            driverProfileId: cover.id,
            previousDriverProfileIds: previousIds,
            tripIds: moving.map((trip) => trip.id),
            handedBack,
          },
        },
      });
      // The regular driver's report for today follows: handed back means they drive.
      if (regularId) {
        const where = { tenantId, driverProfileId: regularId, date: today };
        if (handedBack) await tx.driverAbsence.deleteMany({ where });
        else await tx.driverAbsence.updateMany({ where, data: { coverDriverProfileId: cover.id } });
      }
    });

    const involved = await this.prisma.driverProfile.findMany({
      where: { id: { in: [...previousIds, ...(regularId ? [regularId] : [])] } },
      select: { id: true, user: { select: { id: true, firstName: true, lastName: true } } },
    });
    const regular = involved.find((driver) => driver.id === regularId);
    await this.notifications.send(
      cover.user.id,
      handedBack
        ? coverEnded(bus, directions)
        : coverAssigned(bus, regular ? fullName(regular.user) : null, directions),
    );
    for (const driver of involved.filter((d) => previousIds.includes(d.id))) {
      await this.notifications.send(
        driver.user.id,
        driver.id === regularId
          ? coverReplaced(bus, fullName(cover.user), directions)
          : coverCancelled(bus, directions, handedBack),
      );
    }
    // The bus's own driver hears who drives their bus whenever the cover changes.
    if (regular && !handedBack && !previousIds.includes(regular.id)) {
      await this.notifications.send(
        regular.user.id,
        coverReplaced(bus, fullName(cover.user), directions),
      );
    }
    return { trips: moving.length, planned: false };
  }

  /** Sets the cover for a day whose trips are not made yet. */
  private async plan(
    tenantId: string,
    supervisorUserId: string,
    bus: { id: string; plateNumber: string; name: string | null },
    cover: { id: string; user: { id: string; firstName: string; lastName: string } },
    day: Date,
    today: Date,
  ): Promise<{ trips: number; planned: boolean }> {
    const regularId = await this.regularDriverId(tenantId, bus.id);
    const absence = regularId
      ? await this.prisma.driverAbsence.findFirst({
          where: { tenantId, busId: bus.id, driverProfileId: regularId, date: day },
          select: {
            id: true,
            coverDriverProfileId: true,
            driverProfile: {
              select: { user: { select: { id: true, firstName: true, lastName: true } } },
            },
          },
        })
      : null;
    if (!absence) {
      throw new AppError(
        409,
        day.getTime() === today.getTime() ? 'NO_TRIPS_TO_COVER' : 'NO_ABSENCE',
        day.getTime() === today.getTime()
          ? 'The bus has no trip left to start today'
          : 'The driver has not reported being away that day',
      );
    }
    if (cover.id === regularId) {
      throw new AppError(409, 'DRIVER_BUSY', 'The driver reported they cannot drive that day');
    }
    const candidate = (await this.candidates(tenantId, supervisorUserId, bus.id, day)).find(
      (driver) => driver.profileId === cover.id,
    );
    if (!candidate || candidate.absent || candidate.busy.length > 0) {
      throw new AppError(409, 'DRIVER_BUSY', 'The driver drives elsewhere that day');
    }

    const previous = absence.coverDriverProfileId;
    await this.prisma.$transaction([
      this.prisma.driverAbsence.update({
        where: { id: absence.id },
        data: { coverDriverProfileId: cover.id },
      }),
      this.prisma.auditLog.create({
        data: {
          tenantId,
          actorUserId: supervisorUserId,
          action: 'TRIP_DRIVER_COVERED',
          entityType: 'DriverAbsence',
          entityId: absence.id,
          metadata: {
            driverProfileId: cover.id,
            previousCoverProfileId: previous,
            date: day.toISOString().slice(0, 10),
          },
        },
      }),
    ]);

    const phrase = dayPhrase(day, today);
    const regular = absence.driverProfile.user;
    await this.notifications.send(
      cover.user.id,
      coverAssigned(bus, fullName(regular), BOTH, phrase),
    );
    await this.notifications.send(
      regular.id,
      coverReplaced(bus, fullName(cover.user), BOTH, phrase),
    );
    if (previous && previous !== cover.id) {
      const old = await this.prisma.driverProfile.findUnique({
        where: { id: previous },
        select: { userId: true },
      });
      if (old) await this.notifications.send(old.userId, coverCancelled(bus, BOTH, false, phrase));
    }
    return { trips: 0, planned: true };
  }

  private async regularDriverId(tenantId: string, busId: string): Promise<string | null> {
    const assignment = await this.prisma.driverAssignment.findFirst({
      where: { tenantId, busId, isActive: true },
      orderBy: { assignedAt: 'desc' },
      select: { driverProfileId: true },
    });
    return assignment?.driverProfileId ?? null;
  }

  private async assertSupervisesBus(tenantId: string, userId: string, busId: string) {
    const assignment = await this.prisma.supervisorBusAssignment.findFirst({
      where: {
        tenantId,
        busId,
        isActive: true,
        supervisorProfile: { userId, isActive: true },
      },
      select: { bus: { select: { id: true, plateNumber: true, name: true } } },
    });
    if (!assignment) throw new AppError(404, 'NOT_FOUND', 'Bus not found');
    return assignment.bus;
  }
}
