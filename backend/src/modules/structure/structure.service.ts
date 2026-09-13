import type { Prisma, PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { toPrismaPagination, type Paginated } from '../../utils/pagination';

interface ListOptions {
  page: number;
  limit: number;
  activeOnly?: boolean;
}

export class StructureService {
  constructor(private readonly prisma: PrismaClient) {}

  // ----- Branches -----
  async listBranches(tenantId: string, opts: ListOptions): Promise<Paginated<unknown>> {
    const where = { tenantId, ...(opts.activeOnly ? { isActive: true } : {}) };
    const [items, total] = await Promise.all([
      this.prisma.branch.findMany({
        where,
        ...toPrismaPagination(opts.page, opts.limit),
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.branch.count({ where }),
    ]);
    return { items, page: opts.page, limit: opts.limit, total };
  }

  async createBranch(tenantId: string, data: Omit<Prisma.BranchUncheckedCreateInput, 'tenantId'>) {
    return this.prisma.branch.create({ data: { ...data, tenantId } });
  }

  async updateBranch(tenantId: string, id: string, data: Prisma.BranchUncheckedUpdateInput) {
    await this.assertBranch(tenantId, id);
    return this.prisma.branch.update({ where: { id }, data });
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
    const where = { tenantId, ...(opts.activeOnly ? { isActive: true } : {}) };
    const [items, total] = await Promise.all([
      this.prisma.neighborhood.findMany({
        where,
        ...toPrismaPagination(opts.page, opts.limit),
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.neighborhood.count({ where }),
    ]);
    return { items, page: opts.page, limit: opts.limit, total };
  }

  async createNeighborhood(
    tenantId: string,
    data: Omit<Prisma.NeighborhoodUncheckedCreateInput, 'tenantId'>,
  ) {
    return this.prisma.neighborhood.create({ data: { ...data, tenantId } });
  }

  async updateNeighborhood(
    tenantId: string,
    id: string,
    data: Prisma.NeighborhoodUncheckedUpdateInput,
  ) {
    await this.assertNeighborhood(tenantId, id);
    return this.prisma.neighborhood.update({ where: { id }, data });
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
  async listBuses(tenantId: string, opts: ListOptions): Promise<Paginated<unknown>> {
    const where = { tenantId, ...(opts.activeOnly ? { isActive: true } : {}) };
    const [items, total] = await Promise.all([
      this.prisma.bus.findMany({
        where,
        ...toPrismaPagination(opts.page, opts.limit),
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.bus.count({ where }),
    ]);
    return { items, page: opts.page, limit: opts.limit, total };
  }

  async createBus(tenantId: string, data: Omit<Prisma.BusUncheckedCreateInput, 'tenantId'>) {
    return this.prisma.bus.create({ data: { ...data, tenantId } });
  }

  async updateBus(tenantId: string, id: string, data: Prisma.BusUncheckedUpdateInput) {
    await this.assertBus(tenantId, id);
    return this.prisma.bus.update({ where: { id }, data });
  }

  async archiveBus(tenantId: string, id: string) {
    await this.assertBus(tenantId, id);
    return this.prisma.bus.update({ where: { id }, data: { isActive: false } });
  }

  private async assertBus(tenantId: string, id: string) {
    const existing = await this.prisma.bus.findFirst({ where: { id, tenantId } });
    if (!existing) throw new AppError(404, 'NOT_FOUND', 'Bus not found');
  }

  // ----- Routes -----
  async listRoutes(tenantId: string, opts: ListOptions): Promise<Paginated<unknown>> {
    const where = { tenantId, ...(opts.activeOnly ? { isActive: true } : {}) };
    const [items, total] = await Promise.all([
      this.prisma.route.findMany({
        where,
        ...toPrismaPagination(opts.page, opts.limit),
        orderBy: { createdAt: 'desc' },
        include: {
          routeNeighborhoods: {
            orderBy: { sequenceOrder: 'asc' },
            include: { neighborhood: true },
          },
        },
      }),
      this.prisma.route.count({ where }),
    ]);
    return { items, page: opts.page, limit: opts.limit, total };
  }

  async getRoute(tenantId: string, id: string) {
    const route = await this.prisma.route.findFirst({
      where: { id, tenantId },
      include: {
        routeNeighborhoods: { orderBy: { sequenceOrder: 'asc' }, include: { neighborhood: true } },
      },
    });
    if (!route) throw new AppError(404, 'NOT_FOUND', 'Route not found');
    return route;
  }

  async createRoute(tenantId: string, data: Omit<Prisma.RouteUncheckedCreateInput, 'tenantId'>) {
    if (data.branchId) await this.assertBranch(tenantId, data.branchId);
    return this.prisma.route.create({ data: { ...data, tenantId } });
  }

  async updateRoute(tenantId: string, id: string, data: Prisma.RouteUncheckedUpdateInput) {
    await this.assertRoute(tenantId, id);
    if (data.branchId) await this.assertBranch(tenantId, data.branchId as string);
    return this.prisma.route.update({ where: { id }, data });
  }

  async archiveRoute(tenantId: string, id: string) {
    await this.assertRoute(tenantId, id);
    return this.prisma.route.update({ where: { id }, data: { isActive: false } });
  }

  async setRouteStops(
    tenantId: string,
    routeId: string,
    stops: Array<{ neighborhoodId: string; sequenceOrder: number }>,
  ) {
    const route = await this.prisma.route.findFirst({ where: { id: routeId, tenantId } });
    if (!route) throw new AppError(404, 'NOT_FOUND', 'Route not found');

    const ids = stops.map((s) => s.neighborhoodId);
    const uniqueIds = new Set(ids);
    if (ids.length !== uniqueIds.size) {
      throw new AppError(
        422,
        'DUPLICATE_STOP',
        'Route stops must not contain duplicate neighborhoods',
      );
    }
    const count = await this.prisma.neighborhood.count({ where: { id: { in: ids }, tenantId } });
    if (count !== uniqueIds.size) {
      throw new AppError(
        422,
        'INVALID_STOP',
        'One or more neighborhoods do not belong to this tenant',
      );
    }

    return this.prisma.$transaction([
      this.prisma.routeNeighborhood.deleteMany({ where: { routeId } }),
      ...stops.map((s) =>
        this.prisma.routeNeighborhood.create({
          data: {
            tenantId,
            routeId,
            neighborhoodId: s.neighborhoodId,
            sequenceOrder: s.sequenceOrder,
          },
        }),
      ),
    ]);
  }

  private async assertRoute(tenantId: string, id: string) {
    const existing = await this.prisma.route.findFirst({ where: { id, tenantId } });
    if (!existing) throw new AppError(404, 'NOT_FOUND', 'Route not found');
  }
}
