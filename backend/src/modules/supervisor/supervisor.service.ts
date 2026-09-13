import type { PrismaClient, Role } from '@prisma/client';
import { AppError } from '../../utils/appError';

function dateOnly(d: Date): Date {
  const copy = new Date(d);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

export interface SupervisorBusView {
  bus: { id: string; plateNumber: string; name: string | null };
  trip: { id: string; status: string; routeName: string | null } | null;
  counts: { total: number; boarded: number; missed: number; waiting: number; notReady: number };
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
        busId: true,
        route: { select: { name: true } },
        tripStudents: { select: { status: true } },
      },
    });
    const byBus = new Map(trips.map((t) => [t.busId, t]));

    return buses.map((bus) => {
      const trip = byBus.get(bus.id);
      const students = trip?.tripStudents ?? [];
      const count = (s: string) => students.filter((x) => x.status === s).length;
      return {
        bus,
        trip: trip
          ? { id: trip.id, status: trip.status, routeName: trip.route?.name ?? null }
          : null,
        counts: {
          total: students.length,
          boarded: count('BOARDED'),
          missed: count('MISSED'),
          waiting: count('WAITING'),
          notReady: count('NOT_READY'),
        },
      };
    });
  }
}
