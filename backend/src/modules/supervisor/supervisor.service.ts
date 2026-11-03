import type { PrismaClient, Role } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { dateOnly } from '../../utils/date';

export interface SupervisorBusView {
  bus: { id: string; plateNumber: string; name: string | null };
  trip: {
    id: string;
    status: string;
    direction: string;
    routeName: string | null;
    /** Who drives the trip, and whose trip it was when a cover drives it. */
    driverName: string | null;
    coveredDriverName: string | null;
  } | null;
  /** The bus's own driver. */
  regularDriverName: string | null;
  /** Today's trips not started yet, which a cover driver can take. */
  coverable: number;
  /** Days off its driver reported, today onwards, with the cover if chosen. */
  absences: Array<{
    id: string;
    date: string;
    note: string | null;
    driverName: string;
    coverName: string | null;
  }>;
  /** Who drives each of today's trips, going first. */
  drivers: Array<{
    direction: string;
    status: string;
    driverName: string | null;
    coveredDriverName: string | null;
  }>;
  counts: { total: number; boarded: number; missed: number; waiting: number; notReady: number };
  attendanceSessions: Array<{
    direction: string;
    status: string;
    attending: number;
    absent: number;
    unregistered: number;
  }>;
}

/** The trip a bus card follows: the one running, else the last to finish, else the next due. */
function currentTrip<T extends { status: string; direction: string; completedAt: Date | null }>(
  trips: T[],
): T | undefined {
  const finishedLast = trips
    .filter((trip) => trip.status === 'COMPLETED')
    .sort((a, b) => (b.completedAt?.getTime() ?? 0) - (a.completedAt?.getTime() ?? 0))[0];
  const outboundFirst = [...trips].sort((a, b) => a.direction.localeCompare(b.direction));
  return (
    trips.find((trip) => trip.status === 'IN_PROGRESS') ??
    finishedLast ??
    outboundFirst.find((trip) => trip.status === 'SCHEDULED') ??
    outboundFirst[0]
  );
}

export class SupervisorService {
  constructor(private readonly prisma: PrismaClient) {}

  async getMyBuses(tenantId: string, userId: string, role: Role): Promise<SupervisorBusView[]> {
    const today = dateOnly(new Date());

    let busIds: string[];
    if (role === 'FIELD_SUPERVISOR') {
      const buses = await this.prisma.bus.findMany({
        where: { tenantId, isActive: true },
        select: { id: true },
      });
      busIds = buses.map((b) => b.id);
    } else {
      const profile = await this.prisma.supervisorProfile.findFirst({
        where: { userId, tenantId, isActive: true },
        select: { id: true },
      });
      if (!profile) throw new AppError(404, 'NOT_FOUND', 'Supervisor profile not found');
      const assignments = await this.prisma.supervisorBusAssignment.findMany({
        where: { tenantId, supervisorProfileId: profile.id, isActive: true },
        select: { bus: { select: { id: true, plateNumber: true, name: true } } },
      });
      return this.buildViews(
        tenantId,
        today,
        assignments.map((a) => a.bus),
      );
    }

    const buses = await this.prisma.bus.findMany({
      where: { id: { in: busIds }, tenantId, isActive: true },
      select: { id: true, plateNumber: true, name: true },
      orderBy: { plateNumber: 'asc' },
    });
    return this.buildViews(tenantId, today, buses);
  }

  private async buildViews(
    tenantId: string,
    today: Date,
    buses: Array<{ id: string; plateNumber: string; name: string | null }>,
  ): Promise<SupervisorBusView[]> {
    if (buses.length === 0) return [];
    const trips = await this.prisma.dailyTrip.findMany({
      where: { tenantId, busId: { in: buses.map((b) => b.id) }, tripDate: today },
      select: {
        id: true,
        status: true,
        completedAt: true,
        busId: true,
        route: { select: { name: true } },
        driverProfile: { select: { user: { select: { firstName: true, lastName: true } } } },
        coveredDriverProfile: {
          select: { user: { select: { firstName: true, lastName: true } } },
        },
        tripStudents: { select: { status: true } },
        direction: true,
        attendanceSession: {
          select: { status: true, attendanceIntents: { select: { intent: true } } },
        },
      },
    });
    const regulars = await this.prisma.driverAssignment.findMany({
      where: { tenantId, busId: { in: buses.map((b) => b.id) }, isActive: true },
      select: {
        busId: true,
        driverProfile: { select: { user: { select: { firstName: true, lastName: true } } } },
      },
    });
    const regularByBus = new Map(
      regulars.map((r) => [
        r.busId,
        `${r.driverProfile.user.firstName} ${r.driverProfile.user.lastName}`,
      ]),
    );
    const nameOf = (profile: { user: { firstName: string; lastName: string } } | null) =>
      profile ? `${profile.user.firstName} ${profile.user.lastName}` : null;
    const absences = await this.prisma.driverAbsence.findMany({
      where: { tenantId, busId: { in: buses.map((b) => b.id) }, date: { gte: today } },
      orderBy: { date: 'asc' },
      select: {
        id: true,
        busId: true,
        date: true,
        note: true,
        driverProfile: { select: { user: { select: { firstName: true, lastName: true } } } },
        coverDriverProfile: { select: { user: { select: { firstName: true, lastName: true } } } },
      },
    });
    const byBus = new Map<string | null, (typeof trips)[number][]>();
    for (const trip of trips) byBus.set(trip.busId, [...(byBus.get(trip.busId) ?? []), trip]);

    return buses.map((bus) => {
      const busTrips = byBus.get(bus.id) ?? [];
      const trip = currentTrip(busTrips);
      const students = trip?.tripStudents ?? [];
      const count = (s: string) => students.filter((x) => x.status === s).length;
      return {
        bus,
        trip: trip
          ? {
              id: trip.id,
              status: trip.status,
              direction: trip.direction,
              routeName: trip.route?.name ?? null,
              driverName: nameOf(trip.driverProfile),
              coveredDriverName: nameOf(trip.coveredDriverProfile),
            }
          : null,
        regularDriverName: regularByBus.get(bus.id) ?? null,
        absences: absences
          .filter((absence) => absence.busId === bus.id)
          .map((absence) => ({
            id: absence.id,
            date: absence.date.toISOString().slice(0, 10),
            note: absence.note,
            driverName: nameOf(absence.driverProfile) ?? '',
            coverName: nameOf(absence.coverDriverProfile),
          })),
        coverable: busTrips.filter((candidate) => candidate.status === 'SCHEDULED').length,
        drivers: [...busTrips]
          .sort((a, b) => a.direction.localeCompare(b.direction))
          .map((candidate) => ({
            direction: candidate.direction,
            status: candidate.status,
            driverName: nameOf(candidate.driverProfile),
            coveredDriverName: nameOf(candidate.coveredDriverProfile),
          })),
        counts: {
          total: students.length,
          boarded: count('BOARDED'),
          missed: count('MISSED'),
          waiting: count('WAITING'),
          notReady: count('NOT_READY'),
        },
        attendanceSessions: [...busTrips]
          .sort((a, b) => a.direction.localeCompare(b.direction))
          .map((candidate) => {
            const intents = candidate.attendanceSession?.attendanceIntents ?? [];
            const attending = intents.filter((intent) => intent.intent === 'ATTENDING').length;
            const absent = intents.filter((intent) => intent.intent === 'ABSENT').length;
            return {
              direction: candidate.direction,
              status: candidate.attendanceSession?.status ?? 'OPEN',
              attending,
              absent,
              unregistered: Math.max(0, candidate.tripStudents.length - attending - absent),
            };
          }),
      };
    });
  }
}
