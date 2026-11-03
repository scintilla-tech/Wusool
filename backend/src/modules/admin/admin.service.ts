import type { PrismaClient } from '@prisma/client';
import { dateOnly } from '../../utils/date';
import { clockOf } from '../trips/trips.service';

export class AdminService {
  constructor(private readonly prisma: PrismaClient) {}

  /** Tenant dashboard counts using database-side aggregation (no row loading). */
  async getDashboard(tenantId: string) {
    const today = dateOnly(new Date());
    const [buses, routes, students, drivers, supervisors, fieldSupervisors, tripsToday] =
      await Promise.all([
        this.prisma.bus.count({ where: { tenantId, isActive: true } }),
        this.prisma.route.count({ where: { tenantId, isActive: true } }),
        this.prisma.user.count({ where: { tenantId, role: 'STUDENT', isActive: true } }),
        this.prisma.user.count({ where: { tenantId, role: 'DRIVER', isActive: true } }),
        this.prisma.user.count({ where: { tenantId, role: 'SUPERVISOR', isActive: true } }),
        this.prisma.user.count({ where: { tenantId, role: 'FIELD_SUPERVISOR', isActive: true } }),
        this.prisma.dailyTrip.count({ where: { tenantId, tripDate: today } }),
      ]);

    const tripsByStatus = await this.prisma.dailyTrip.groupBy({
      by: ['status'],
      where: { tenantId, tripDate: today },
      _count: { _all: true },
    });

    return {
      buses,
      routes,
      students,
      drivers,
      supervisors,
      fieldSupervisors,
      tripsToday,
      tripsByStatus: tripsByStatus.map((t) => ({ status: t.status, count: t._count._all })),
    };
  }

  /** University settings the admin app changes. */
  async getSettings(tenantId: string) {
    const tenant = await this.prisma.tenant.findUniqueOrThrow({
      where: { id: tenantId },
      select: { autoTrips: true, autoTripMinute: true },
    });
    return { autoTrips: tenant.autoTrips, autoTripTime: clockOf(tenant.autoTripMinute) };
  }

  /** `autoTripTime` is "HH:MM", Riyadh time. */
  async updateSettings(
    tenantId: string,
    actorUserId: string,
    input: { autoTrips?: boolean; autoTripTime?: string },
  ) {
    const minute = input.autoTripTime
      ? Number(input.autoTripTime.slice(0, 2)) * 60 + Number(input.autoTripTime.slice(3, 5))
      : undefined;
    await this.prisma.$transaction([
      this.prisma.tenant.update({
        where: { id: tenantId },
        data: {
          ...(input.autoTrips !== undefined ? { autoTrips: input.autoTrips } : {}),
          ...(minute !== undefined ? { autoTripMinute: minute } : {}),
        },
      }),
      this.prisma.auditLog.create({
        data: {
          tenantId,
          actorUserId,
          action:
            input.autoTrips === undefined
              ? 'AUTO_TRIPS_TIME_CHANGED'
              : input.autoTrips
                ? 'AUTO_TRIPS_RESUMED'
                : 'AUTO_TRIPS_PAUSED',
          entityType: 'Tenant',
          entityId: tenantId,
          metadata: input,
        },
      }),
    ]);
    return this.getSettings(tenantId);
  }
}
