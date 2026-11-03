import { Prisma, type PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { toPrismaPagination, type Paginated } from '../../utils/pagination';

interface ListOptions {
  page: number;
  limit: number;
  activeOnly?: boolean;
  /** Search text, matched against names, codes and plate numbers. */
  q?: string;
}

const contains = (q: string) => ({ contains: q, mode: 'insensitive' as const });

/** The person in an active assignment, as bus screens show them. */
const staffSelect = {
  id: true,
  employeeId: true,
  user: { select: { id: true, firstName: true, lastName: true, phone: true, isActive: true } },
} as const;

const busInclude = {
  route: { select: { id: true, name: true, code: true, isActive: true } },
  driverAssignments: {
    where: { isActive: true },
    orderBy: { assignedAt: 'desc' },
    take: 1,
    select: { driverProfile: { select: staffSelect } },
  },
  supervisorBusAssignments: {
    where: { isActive: true },
    orderBy: { assignedAt: 'desc' },
    take: 1,
    select: { supervisorProfile: { select: staffSelect } },
  },
} satisfies Prisma.BusInclude;

type BusRecord = Prisma.BusGetPayload<{ include: typeof busInclude }>;
type StaffRecord = Prisma.DriverProfileGetPayload<{ select: typeof staffSelect }>;

function toStaffRef(profile: StaffRecord | undefined) {
  if (!profile) return null;
  return {
    id: profile.user.id,
    profileId: profile.id,
    employeeId: profile.employeeId,
    firstName: profile.user.firstName,
    lastName: profile.user.lastName,
    phone: profile.user.phone,
    isActive: profile.user.isActive,
  };
}

function toBusDto(bus: BusRecord) {
  const { driverAssignments, supervisorBusAssignments, ...fields } = bus;
  return {
    ...fields,
    driver: toStaffRef(driverAssignments[0]?.driverProfile),
    supervisor: toStaffRef(supervisorBusAssignments[0]?.supervisorProfile),
  };
}

const routeInclude = {
  branch: { select: { id: true, name: true } },
  bus: { select: { id: true, plateNumber: true, name: true, isActive: true } },
  routeNeighborhoods: {
    orderBy: { sequenceOrder: 'asc' },
    select: { sequenceOrder: true, neighborhood: { select: { id: true, name: true } } },
  },
  _count: { select: { studentAssignments: { where: { isActive: true } } } },
} satisfies Prisma.RouteInclude;

type RouteRecord = Prisma.RouteGetPayload<{ include: typeof routeInclude }>;

function toRouteDto(route: RouteRecord) {
  const { _count, ...fields } = route;
  return { ...fields, studentCount: _count.studentAssignments };
}

/**
 * Turns a unique-constraint failure into a clear conflict: `codes` maps a
 * column of the constraint to the error to answer with.
 */
function rethrowTaken(error: unknown, codes: Record<string, [string, string]>): never {
  if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
    const target = JSON.stringify(error.meta?.target ?? '');
    const entries = Object.entries(codes);
    const [, [code, message]] = entries.find(([column]) => target.includes(column)) ?? entries[0];
    throw new AppError(409, code, message);
  }
  throw error;
}

const BUS_TAKEN: Record<string, [string, string]> = {
  plateNumber: ['PLATE_TAKEN', 'Another bus has this plate number'],
  routeId: ['ROUTE_TAKEN', 'Another bus runs this route'],
};
const ROUTE_TAKEN: Record<string, [string, string]> = {
  code: ['CODE_TAKEN', 'Another route has this code'],
};
const BRANCH_TAKEN: Record<string, [string, string]> = {
  code: ['CODE_TAKEN', 'Another campus has this code'],
};

export class StructureService {
  constructor(private readonly prisma: PrismaClient) {}

  // ----- Branches -----
  async listBranches(tenantId: string, opts: ListOptions): Promise<Paginated<unknown>> {
    const where = {
      tenantId,
      ...(opts.activeOnly ? { isActive: true } : {}),
      ...(opts.q ? { name: contains(opts.q) } : {}),
    };
    const [items, total] = await Promise.all([
      this.prisma.branch.findMany({
        where,
        ...toPrismaPagination(opts.page, opts.limit),
        orderBy: { createdAt: 'desc' },
        include: { _count: { select: { routes: { where: { isActive: true } } } } },
      }),
      this.prisma.branch.count({ where }),
    ]);
    return {
      items: items.map(({ _count, ...branch }) => ({ ...branch, routeCount: _count.routes })),
      page: opts.page,
      limit: opts.limit,
      total,
    };
  }

  async createBranch(tenantId: string, data: Omit<Prisma.BranchUncheckedCreateInput, 'tenantId'>) {
    try {
      return await this.prisma.branch.create({ data: { ...data, tenantId } });
    } catch (error) {
      rethrowTaken(error, BRANCH_TAKEN);
    }
  }

  async updateBranch(tenantId: string, id: string, data: Prisma.BranchUncheckedUpdateInput) {
    await this.assertBranch(tenantId, id);
    try {
      return await this.prisma.branch.update({ where: { id }, data });
    } catch (error) {
      rethrowTaken(error, BRANCH_TAKEN);
    }
  }

  async archiveBranch(tenantId: string, id: string) {
    await this.assertBranch(tenantId, id);
    return this.prisma.branch.update({ where: { id }, data: { isActive: false } });
  }

  private async assertBranch(tenantId: string, id: string) {
    const existing = await this.prisma.branch.findFirst({ where: { id, tenantId } });
    if (!existing) throw new AppError(404, 'NOT_FOUND', 'Branch not found');
  }

  // ----- Neighborhoods -----
  async listNeighborhoods(tenantId: string, opts: ListOptions): Promise<Paginated<unknown>> {
    const where = {
      tenantId,
      ...(opts.activeOnly ? { isActive: true } : {}),
      ...(opts.q ? { name: contains(opts.q) } : {}),
    };
    const [items, total] = await Promise.all([
      this.prisma.neighborhood.findMany({
        where,
        ...toPrismaPagination(opts.page, opts.limit),
        orderBy: { createdAt: 'desc' },
        include: {
          _count: { select: { routeNeighborhoods: { where: { route: { isActive: true } } } } },
        },
      }),
      this.prisma.neighborhood.count({ where }),
    ]);
    return {
      items: items.map(({ _count, ...hood }) => ({
        ...hood,
        routeCount: _count.routeNeighborhoods,
      })),
      page: opts.page,
      limit: opts.limit,
      total,
    };
  }

  async createNeighborhood(
    tenantId: string,
    data: Omit<Prisma.NeighborhoodUncheckedCreateInput, 'tenantId'>,
  ) {
    await this.assertNeighborhoodNameFree(tenantId, data.name);
    return this.prisma.neighborhood.create({ data: { ...data, tenantId } });
  }

  async updateNeighborhood(
    tenantId: string,
    id: string,
    data: Prisma.NeighborhoodUncheckedUpdateInput,
  ) {
    await this.assertNeighborhood(tenantId, id);
    if (typeof data.name === 'string')
      await this.assertNeighborhoodNameFree(tenantId, data.name, id);
    return this.prisma.neighborhood.update({ where: { id }, data });
  }

  /** Two neighborhoods with one name could not be told apart as stops. */
  private async assertNeighborhoodNameFree(tenantId: string, name: string, exceptId?: string) {
    const same = await this.prisma.neighborhood.findFirst({
      where: {
        tenantId,
        isActive: true,
        name: { equals: name.trim(), mode: 'insensitive' },
        ...(exceptId ? { id: { not: exceptId } } : {}),
      },
      select: { id: true },
    });
    if (same) throw new AppError(409, 'NAME_TAKEN', 'Another neighborhood has this name');
  }

  async archiveNeighborhood(tenantId: string, id: string) {
    await this.assertNeighborhood(tenantId, id);
    return this.prisma.neighborhood.update({ where: { id }, data: { isActive: false } });
  }

  private async assertNeighborhood(tenantId: string, id: string) {
    const existing = await this.prisma.neighborhood.findFirst({ where: { id, tenantId } });
    if (!existing) throw new AppError(404, 'NOT_FOUND', 'Neighborhood not found');
  }

  // ----- Buses -----
  /** Buses with the driver and supervisor currently working on each. */
  async listBuses(tenantId: string, opts: ListOptions): Promise<Paginated<unknown>> {
    const where = {
      tenantId,
      ...(opts.activeOnly ? { isActive: true } : {}),
      ...(opts.q ? { OR: [{ plateNumber: contains(opts.q) }, { name: contains(opts.q) }] } : {}),
    };
    const [items, total] = await Promise.all([
      this.prisma.bus.findMany({
        where,
        ...toPrismaPagination(opts.page, opts.limit),
        orderBy: { createdAt: 'desc' },
        include: busInclude,
      }),
      this.prisma.bus.count({ where }),
    ]);
    return { items: items.map(toBusDto), page: opts.page, limit: opts.limit, total };
  }

  async getBus(tenantId: string, id: string) {
    const bus = await this.prisma.bus.findFirst({ where: { id, tenantId }, include: busInclude });
    if (!bus) throw new AppError(404, 'NOT_FOUND', 'Bus not found');
    return toBusDto(bus);
  }

  async createBus(tenantId: string, data: Omit<Prisma.BusUncheckedCreateInput, 'tenantId'>) {
    if (data.routeId) await this.assertFixedRoute(tenantId, data.routeId);
    try {
      const bus = await this.prisma.bus.create({ data: { ...data, tenantId } });
      return await this.getBus(tenantId, bus.id);
    } catch (error) {
      rethrowTaken(error, BUS_TAKEN);
    }
  }

  async updateBus(tenantId: string, id: string, data: Prisma.BusUncheckedUpdateInput) {
    await this.assertBus(tenantId, id);
    if (typeof data.routeId === 'string') await this.assertFixedRoute(tenantId, data.routeId);
    try {
      await this.prisma.$transaction(async (tx) => {
        // A bus out of service leaves its route free for another bus.
        const leaving = data.isActive === false ? { routeId: null } : {};
        await tx.bus.update({ where: { id }, data: { ...data, ...leaving } });
        if (data.isActive === false) await this.endBusAssignments(tx, tenantId, id);
      });
    } catch (error) {
      rethrowTaken(error, BUS_TAKEN);
    }
    return this.getBus(tenantId, id);
  }

  /** A route a bus can run every day: the tenant's, and in service. */
  private async assertFixedRoute(tenantId: string, routeId: string) {
    const route = await this.prisma.route.findFirst({
      where: { id: routeId, tenantId, isActive: true },
      select: { id: true },
    });
    if (!route) throw new AppError(404, 'NOT_FOUND', 'Route not found or out of service');
  }

  /** Takes the bus out of service, off its driver and supervisor, and off its route. */
  async archiveBus(tenantId: string, id: string) {
    return this.updateBus(tenantId, id, { isActive: false });
  }

  private async endBusAssignments(tx: Prisma.TransactionClient, tenantId: string, busId: string) {
    const where = { tenantId, busId, isActive: true };
    await tx.driverAssignment.updateMany({ where, data: { isActive: false } });
    await tx.supervisorBusAssignment.updateMany({ where, data: { isActive: false } });
  }

  private async assertBus(tenantId: string, id: string) {
    const existing = await this.prisma.bus.findFirst({ where: { id, tenantId } });
    if (!existing) throw new AppError(404, 'NOT_FOUND', 'Bus not found');
  }

  // ----- Routes -----
  /** Routes with their stops in order and how many students ride each. */
  async listRoutes(tenantId: string, opts: ListOptions): Promise<Paginated<unknown>> {
    const where = {
      tenantId,
      ...(opts.activeOnly ? { isActive: true } : {}),
      ...(opts.q ? { OR: [{ name: contains(opts.q) }, { code: contains(opts.q) }] } : {}),
    };
    const [items, total] = await Promise.all([
      this.prisma.route.findMany({
        where,
        ...toPrismaPagination(opts.page, opts.limit),
        orderBy: { createdAt: 'desc' },
        include: routeInclude,
      }),
      this.prisma.route.count({ where }),
    ]);
    return { items: items.map(toRouteDto), page: opts.page, limit: opts.limit, total };
  }

  async getRoute(tenantId: string, id: string) {
    const route = await this.prisma.route.findFirst({
      where: { id, tenantId },
      include: routeInclude,
    });
    if (!route) throw new AppError(404, 'NOT_FOUND', 'Route not found');
    return toRouteDto(route);
  }

  async createRoute(
    tenantId: string,
    input: Omit<Prisma.RouteUncheckedCreateInput, 'tenantId'> & { stopIds?: string[] },
  ) {
    const { stopIds, ...data } = input;
    if (data.branchId) await this.assertBranch(tenantId, data.branchId);
    if (stopIds) await this.assertStops(tenantId, stopIds);
    try {
      const route = await this.prisma.$transaction(async (tx) => {
        const created = await tx.route.create({ data: { ...data, tenantId } });
        if (stopIds) await this.writeStops(tx, tenantId, created.id, stopIds);
        return created;
      });
      return await this.getRoute(tenantId, route.id);
    } catch (error) {
      rethrowTaken(error, ROUTE_TAKEN);
    }
  }

  async updateRoute(
    tenantId: string,
    id: string,
    input: Prisma.RouteUncheckedUpdateInput & { stopIds?: string[] },
  ) {
    const { stopIds, ...data } = input;
    await this.assertRoute(tenantId, id);
    if (data.branchId) await this.assertBranch(tenantId, data.branchId as string);
    if (stopIds) await this.assertStops(tenantId, stopIds);
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.route.update({ where: { id }, data });
        if (stopIds) {
          await tx.routeNeighborhood.deleteMany({ where: { routeId: id } });
          await this.writeStops(tx, tenantId, id, stopIds);
        }
        // Students of a route out of service have no ride; they need another
        // route. Its bus no longer runs it.
        if (data.isActive === false) {
          await tx.studentAssignment.updateMany({
            where: { tenantId, routeId: id, isActive: true },
            data: { isActive: false },
          });
          await tx.bus.updateMany({ where: { tenantId, routeId: id }, data: { routeId: null } });
        }
      });
    } catch (error) {
      rethrowTaken(error, ROUTE_TAKEN);
    }
    return this.getRoute(tenantId, id);
  }

  /** Takes the route out of service and off its students. */
  async archiveRoute(tenantId: string, id: string) {
    return this.updateRoute(tenantId, id, { isActive: false });
  }

  private async writeStops(
    tx: Prisma.TransactionClient,
    tenantId: string,
    routeId: string,
    stopIds: string[],
  ) {
    if (stopIds.length === 0) return;
    await tx.routeNeighborhood.createMany({
      data: stopIds.map((neighborhoodId, index) => ({
        tenantId,
        routeId,
        neighborhoodId,
        sequenceOrder: index,
      })),
    });
  }

  /** Stops must be distinct neighborhoods of this tenant. */
  private async assertStops(tenantId: string, ids: string[]) {
    const uniqueIds = new Set(ids);
    if (ids.length !== uniqueIds.size) {
      throw new AppError(
        422,
        'DUPLICATE_STOP',
        'Route stops must not contain duplicate neighborhoods',
      );
    }
    if (uniqueIds.size === 0) return;
    const count = await this.prisma.neighborhood.count({
      where: { id: { in: [...uniqueIds] }, tenantId },
    });
    if (count !== uniqueIds.size) {
      throw new AppError(
        422,
        'INVALID_STOP',
        'One or more neighborhoods do not belong to this tenant',
      );
    }
  }

  async setRouteStops(
    tenantId: string,
    routeId: string,
    stops: Array<{ neighborhoodId: string; sequenceOrder: number }>,
  ) {
    const route = await this.prisma.route.findFirst({ where: { id: routeId, tenantId } });
    if (!route) throw new AppError(404, 'NOT_FOUND', 'Route not found');

    await this.assertStops(
      tenantId,
      stops.map((s) => s.neighborhoodId),
    );

    return this.prisma.$transaction([
      this.prisma.routeNeighborhood.deleteMany({ where: { routeId } }),
      this.prisma.routeNeighborhood.createMany({
        data: stops.map((s) => ({
          tenantId,
          routeId,
          neighborhoodId: s.neighborhoodId,
          sequenceOrder: s.sequenceOrder,
        })),
      }),
    ]);
  }

  private async assertRoute(tenantId: string, id: string) {
    const existing = await this.prisma.route.findFirst({ where: { id, tenantId } });
    if (!existing) throw new AppError(404, 'NOT_FOUND', 'Route not found');
  }
}
