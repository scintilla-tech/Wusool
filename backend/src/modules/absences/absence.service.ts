import { Prisma, type PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { dateOnly } from '../../utils/date';
import type { NotificationService } from '../notifications/notification.service';
import { absenceCancelled, dayPhrase, driverAbsent } from '../notifications/trip-messages';

/** How far ahead a driver can report a day off. */
export const MAX_DAYS_AHEAD = 60;

const DAY_MS = 86_400_000;

const nameOf = (user: { firstName: string; lastName: string }) =>
  `${user.firstName} ${user.lastName}`;

const absenceSelect = {
  id: true,
  date: true,
  note: true,
  busId: true,
  driverProfile: { select: { id: true, user: { select: { firstName: true, lastName: true } } } },
  coverDriverProfile: {
    select: { id: true, user: { select: { firstName: true, lastName: true } } },
  },
} satisfies Prisma.DriverAbsenceSelect;

type AbsenceRecord = Prisma.DriverAbsenceGetPayload<{ select: typeof absenceSelect }>;

export interface AbsenceDto {
  id: string;
  /** YYYY-MM-DD */
  date: string;
  note: string | null;
  busId: string;
  driverName: string;
  coverName: string | null;
}

function toDto(absence: AbsenceRecord): AbsenceDto {
  return {
    id: absence.id,
    date: absence.date.toISOString().slice(0, 10),
    note: absence.note,
    busId: absence.busId,
    driverName: nameOf(absence.driverProfile.user),
    coverName: absence.coverDriverProfile ? nameOf(absence.coverDriverProfile.user) : null,
  };
}

/**
 * A driver tells the bus's supervisor they cannot drive on a day; the
 * supervisor picks a cover (see CoverService) and the day's trips are made
 * with the cover as driver.
 */
export class AbsenceService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly notifications: NotificationService,
  ) {}

  async listForDriver(tenantId: string, driverUserId: string): Promise<AbsenceDto[]> {
    const driver = await this.driver(tenantId, driverUserId);
    const absences = await this.prisma.driverAbsence.findMany({
      where: { tenantId, driverProfileId: driver.id, date: { gte: dateOnly(new Date()) } },
      orderBy: { date: 'asc' },
      select: absenceSelect,
    });
    return absences.map(toDto);
  }

  /** Days off coming up on these buses, for their supervisors. */
  async forBuses(tenantId: string, busIds: string[]): Promise<AbsenceDto[]> {
    if (busIds.length === 0) return [];
    const absences = await this.prisma.driverAbsence.findMany({
      where: { tenantId, busId: { in: busIds }, date: { gte: dateOnly(new Date()) } },
      orderBy: { date: 'asc' },
      select: absenceSelect,
    });
    return absences.map(toDto);
  }

  async report(
    tenantId: string,
    driverUserId: string,
    input: { date: Date; note?: string },
  ): Promise<AbsenceDto> {
    const driver = await this.driver(tenantId, driverUserId);
    const bus = driver.driverAssignments[0]?.bus;
    if (!bus) throw new AppError(409, 'NO_BUS', 'The driver is not assigned to a bus');
    const today = dateOnly(new Date());
    const day = dateOnly(input.date);
    const ahead = Math.round((day.getTime() - today.getTime()) / DAY_MS);
    if (ahead < 0 || ahead > MAX_DAYS_AHEAD) {
      throw new AppError(422, 'INVALID_DATE', `Report today or up to ${MAX_DAYS_AHEAD} days ahead`);
    }
    const supervisors = await this.supervisorUserIds(tenantId, bus.id);
    if (supervisors.length === 0) {
      throw new AppError(409, 'NO_SUPERVISOR', 'The bus has no supervisor to pick a cover');
    }

    let absence: AbsenceRecord;
    try {
      absence = await this.prisma.driverAbsence.create({
        data: {
          tenantId,
          driverProfileId: driver.id,
          busId: bus.id,
          date: day,
          note: input.note?.trim() || null,
        },
        select: absenceSelect,
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new AppError(409, 'ABSENCE_EXISTS', 'Already reported for this day');
      }
      throw error;
    }
    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorUserId: driverUserId,
        action: 'DRIVER_ABSENCE_REPORTED',
        entityType: 'DriverAbsence',
        entityId: absence.id,
        metadata: { date: day.toISOString().slice(0, 10), busId: bus.id },
      },
    });
    await this.notifications.sendToAll(
      supervisors,
      driverAbsent(nameOf(driver.user), bus, dayPhrase(day, today), absence.note),
    );
    return toDto(absence);
  }

  /** The driver can drive after all; only before a cover is chosen. */
  async cancel(tenantId: string, driverUserId: string, id: string): Promise<void> {
    const driver = await this.driver(tenantId, driverUserId);
    const today = dateOnly(new Date());
    const absence = await this.prisma.driverAbsence.findFirst({
      where: { id, tenantId, driverProfileId: driver.id, date: { gte: today } },
      select: {
        id: true,
        date: true,
        coverDriverProfileId: true,
        bus: { select: { id: true, plateNumber: true, name: true } },
      },
    });
    if (!absence) throw new AppError(404, 'NOT_FOUND', 'Absence not found');
    if (absence.coverDriverProfileId) {
      throw new AppError(409, 'COVER_CHOSEN', 'A cover is chosen; ask the supervisor');
    }
    await this.prisma.driverAbsence.delete({ where: { id } });
    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorUserId: driverUserId,
        action: 'DRIVER_ABSENCE_CANCELLED',
        entityType: 'DriverAbsence',
        entityId: id,
      },
    });
    await this.notifications.sendToAll(
      await this.supervisorUserIds(tenantId, absence.bus.id),
      absenceCancelled(nameOf(driver.user), absence.bus, dayPhrase(absence.date, today)),
    );
  }

  async supervisorUserIds(tenantId: string, busId: string): Promise<string[]> {
    const assignments = await this.prisma.supervisorBusAssignment.findMany({
      where: {
        tenantId,
        busId,
        isActive: true,
        supervisorProfile: { isActive: true, user: { isActive: true } },
      },
      select: { supervisorProfile: { select: { userId: true } } },
    });
    return assignments.map((a) => a.supervisorProfile.userId);
  }

  private async driver(tenantId: string, userId: string) {
    const driver = await this.prisma.driverProfile.findFirst({
      where: { userId, tenantId, isActive: true },
      select: {
        id: true,
        user: { select: { firstName: true, lastName: true } },
        driverAssignments: {
          where: { isActive: true, bus: { isActive: true } },
          orderBy: { assignedAt: 'desc' },
          take: 1,
          select: { bus: { select: { id: true, plateNumber: true, name: true } } },
        },
      },
    });
    if (!driver) throw new AppError(404, 'NOT_FOUND', 'Driver profile not found');
    return driver;
  }
}
