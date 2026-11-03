import type { PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import type { NotificationService } from '../notifications/notification.service';
import { routeByDriver } from '../notifications/trip-messages';
import type { StructureService } from '../structure/structure.service';

export interface DriverRouteInput {
  name: string;
  branchId?: string | null;
  stopIds: string[];
}

/**
 * A driver whose bus has no fixed route builds it once: its name, campus and
 * stops. It becomes the bus's fixed route, so trips are made every school
 * day; the driver (and admins) can edit it afterwards.
 */
export class DriverRouteService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly structure: StructureService,
    private readonly notifications: NotificationService,
  ) {}

  /** Campuses and neighborhoods to build the route from. */
  async options(tenantId: string) {
    const [campuses, neighborhoods] = await Promise.all([
      this.prisma.branch.findMany({
        where: { tenantId, isActive: true },
        orderBy: { name: 'asc' },
        select: { id: true, name: true },
        take: 100,
      }),
      this.prisma.neighborhood.findMany({
        where: { tenantId, isActive: true },
        orderBy: { name: 'asc' },
        select: { id: true, name: true },
        take: 500,
      }),
    ]);
    return { campuses, neighborhoods };
  }

  /** A neighborhood the route stops at that nobody added yet. */
  async addNeighborhood(tenantId: string, name: string) {
    return this.structure.createNeighborhood(tenantId, { name });
  }

  async create(tenantId: string, driverUserId: string, input: DriverRouteInput) {
    const { driver, bus } = await this.driverBus(tenantId, driverUserId);
    if (bus.route?.isActive) {
      throw new AppError(409, 'ROUTE_EXISTS', 'The bus already has a fixed route');
    }
    const route = await this.structure.createRoute(tenantId, {
      name: input.name,
      ...(input.branchId ? { branchId: input.branchId } : {}),
      stopIds: input.stopIds,
    });
    await this.prisma.bus.update({ where: { id: bus.id }, data: { routeId: route.id } });
    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorUserId: driverUserId,
        action: 'ROUTE_CREATED_BY_DRIVER',
        entityType: 'Route',
        entityId: route.id,
        metadata: { busId: bus.id },
      },
    });
    const admins = await this.prisma.user.findMany({
      where: { tenantId, role: 'UNIVERSITY_ADMIN', isActive: true },
      select: { id: true },
    });
    await this.notifications.sendToAll(
      admins.map((admin) => admin.id),
      routeByDriver(`${driver.user.firstName} ${driver.user.lastName}`, route.name, bus),
    );
    return route;
  }

  /** Renames the bus's fixed route, or changes its campus or stops. */
  async update(tenantId: string, driverUserId: string, input: Partial<DriverRouteInput>) {
    const { bus } = await this.driverBus(tenantId, driverUserId);
    if (!bus.route?.isActive) {
      throw new AppError(409, 'NO_ROUTE', 'The bus has no fixed route');
    }
    const route = await this.structure.updateRoute(tenantId, bus.route.id, input);
    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorUserId: driverUserId,
        action: 'ROUTE_EDITED_BY_DRIVER',
        entityType: 'Route',
        entityId: bus.route.id,
        metadata: { fields: Object.keys(input) },
      },
    });
    return route;
  }

  private async driverBus(tenantId: string, driverUserId: string) {
    const driver = await this.prisma.driverProfile.findFirst({
      where: { userId: driverUserId, tenantId, isActive: true },
      select: {
        id: true,
        user: { select: { firstName: true, lastName: true } },
        driverAssignments: {
          where: { isActive: true, bus: { isActive: true } },
          orderBy: { assignedAt: 'desc' },
          take: 1,
          select: {
            bus: {
              select: {
                id: true,
                plateNumber: true,
                name: true,
                route: { select: { id: true, isActive: true } },
              },
            },
          },
        },
      },
    });
    if (!driver) throw new AppError(404, 'NOT_FOUND', 'Driver profile not found');
    const bus = driver.driverAssignments[0]?.bus;
    if (!bus) throw new AppError(409, 'NO_BUS', 'The driver is not assigned to a bus');
    return { driver, bus };
  }
}
