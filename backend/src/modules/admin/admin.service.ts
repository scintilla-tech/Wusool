import type { PrismaClient } from '@prisma/client';
import { dateOnly } from '../../utils/date';

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
}
