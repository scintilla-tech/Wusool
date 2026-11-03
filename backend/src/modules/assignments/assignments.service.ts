import type { PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { toPrismaPagination, type Paginated } from '../../utils/pagination';

export class AssignmentsService {
  constructor(private readonly prisma: PrismaClient) {}

  // ----- Student assignments -----
  async listStudentAssignments(
    tenantId: string,
    page: number,
    limit: number,
  ): Promise<Paginated<unknown>> {
    const where = { tenantId, isActive: true };
    const [items, total] = await Promise.all([
      this.prisma.studentAssignment.findMany({
        where,
        ...toPrismaPagination(page, limit),
        select: {
          id: true,
          studentProfileId: true,
          routeId: true,
          branchId: true,
          isActive: true,
          assignedAt: true,
          studentProfile: { select: { id: true, studentId: true, userId: true } },
          route: { select: { id: true, name: true, code: true } },
          branch: { select: { id: true, name: true, code: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.studentAssignment.count({ where }),
    ]);
    return { items, page, limit, total };
  }

  async assignStudent(
    tenantId: string,
    input: { studentProfileId: string; routeId?: string; branchId?: string },
  ) {
    await this.assertStudentProfile(tenantId, input.studentProfileId);
    const route = input.routeId ? await this.assertRoute(tenantId, input.routeId) : null;
    if (input.branchId) await this.assertBranch(tenantId, input.branchId);

    return this.prisma.$transaction(async (tx) => {
      await tx.studentAssignment.updateMany({
        where: { tenantId, studentProfileId: input.studentProfileId, isActive: true },
        data: { isActive: false },
      });
      return tx.studentAssignment.create({
        data: {
          tenantId,
          studentProfileId: input.studentProfileId,
          routeId: input.routeId ?? null,
          // A route serves one campus; students on it go there unless told otherwise.
          branchId: input.branchId ?? route?.branchId ?? null,
          isActive: true,
        },
      });
    });
  }

  /**
   * Puts students on a route in one step. Students on another route move;
   * those already on this one are left as they are.
   */
  async assignStudentsToRoute(
    tenantId: string,
    input: { routeId: string; studentProfileIds: string[] },
  ): Promise<{ assigned: number }> {
    const route = await this.assertRoute(tenantId, input.routeId);
    const ids = [...new Set(input.studentProfileIds)];
    const found = await this.prisma.studentProfile.count({
      where: { id: { in: ids }, tenantId, isActive: true, user: { isActive: true } },
    });
    if (found !== ids.length) {
      throw new AppError(
        422,
        'INVALID_STUDENTS',
        'One or more students were not found or are disabled',
      );
    }
    const already = await this.prisma.studentAssignment.findMany({
      where: { tenantId, routeId: route.id, isActive: true, studentProfileId: { in: ids } },
      select: { studentProfileId: true },
    });
    const onRoute = new Set(already.map((assignment) => assignment.studentProfileId));
    const moving = ids.filter((id) => !onRoute.has(id));
    if (moving.length === 0) return { assigned: 0 };

    await this.prisma.$transaction([
      this.prisma.studentAssignment.updateMany({
        where: { tenantId, studentProfileId: { in: moving }, isActive: true },
        data: { isActive: false },
      }),
      this.prisma.studentAssignment.createMany({
        data: moving.map((studentProfileId) => ({
          tenantId,
          studentProfileId,
          routeId: route.id,
          branchId: route.branchId,
          isActive: true,
        })),
      }),
    ]);
    return { assigned: moving.length };
  }

  async unassignStudent(tenantId: string, studentProfileId: string) {
    await this.prisma.studentAssignment.updateMany({
      where: { tenantId, studentProfileId, isActive: true },
      data: { isActive: false },
    });
  }

  // ----- Driver assignments -----
  async listDriverAssignments(
    tenantId: string,
    page: number,
    limit: number,
  ): Promise<Paginated<unknown>> {
    const where = { tenantId, isActive: true };
    const [items, total] = await Promise.all([
      this.prisma.driverAssignment.findMany({
        where,
        ...toPrismaPagination(page, limit),
        select: {
          id: true,
          driverProfileId: true,
          busId: true,
          isActive: true,
          assignedAt: true,
          driverProfile: { select: { id: true, employeeId: true, userId: true } },
          bus: { select: { id: true, plateNumber: true, name: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.driverAssignment.count({ where }),
    ]);
    return { items, page, limit, total };
  }

  async assignDriver(tenantId: string, input: { driverProfileId: string; busId: string }) {
    await this.assertDriverProfile(tenantId, input.driverProfileId);
    await this.assertBus(tenantId, input.busId);

    return this.prisma.$transaction(async (tx) => {
      await tx.driverAssignment.updateMany({
        where: {
          tenantId,
          OR: [{ busId: input.busId }, { driverProfileId: input.driverProfileId }],
          isActive: true,
        },
        data: { isActive: false },
      });
      return tx.driverAssignment.create({
        data: {
          tenantId,
          driverProfileId: input.driverProfileId,
          busId: input.busId,
          isActive: true,
        },
      });
    });
  }

  async unassignDriver(tenantId: string, busId: string) {
    await this.prisma.driverAssignment.updateMany({
      where: { tenantId, busId, isActive: true },
      data: { isActive: false },
    });
  }

  // ----- Supervisor assignments -----
  async listSupervisorAssignments(
    tenantId: string,
    page: number,
    limit: number,
  ): Promise<Paginated<unknown>> {
    const where = { tenantId, isActive: true };
    const [items, total] = await Promise.all([
      this.prisma.supervisorBusAssignment.findMany({
        where,
        ...toPrismaPagination(page, limit),
        select: {
          id: true,
          supervisorProfileId: true,
          busId: true,
          isActive: true,
          assignedAt: true,
          supervisorProfile: { select: { id: true, employeeId: true, userId: true } },
          bus: { select: { id: true, plateNumber: true, name: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.supervisorBusAssignment.count({ where }),
    ]);
    return { items, page, limit, total };
  }

  async assignSupervisor(tenantId: string, input: { supervisorProfileId: string; busId: string }) {
    await this.assertSupervisorProfile(tenantId, input.supervisorProfileId);
    await this.assertBus(tenantId, input.busId);

    return this.prisma.$transaction(async (tx) => {
      await tx.supervisorBusAssignment.updateMany({
        where: {
          tenantId,
          OR: [{ busId: input.busId }, { supervisorProfileId: input.supervisorProfileId }],
          isActive: true,
        },
        data: { isActive: false },
      });
      return tx.supervisorBusAssignment.create({
        data: {
          tenantId,
          supervisorProfileId: input.supervisorProfileId,
          busId: input.busId,
          isActive: true,
        },
      });
    });
  }

  async unassignSupervisor(tenantId: string, busId: string) {
    await this.prisma.supervisorBusAssignment.updateMany({
      where: { tenantId, busId, isActive: true },
      data: { isActive: false },
    });
  }

  // ----- Cross-tenant assertions (require tenant + active profile and account) -----
  private async assertStudentProfile(tenantId: string, id: string) {
    const found = await this.prisma.studentProfile.findFirst({
      where: { id, tenantId, isActive: true, user: { isActive: true } },
    });
    if (!found) throw new AppError(404, 'NOT_FOUND', 'Student profile not found or inactive');
  }

  private async assertDriverProfile(tenantId: string, id: string) {
    const found = await this.prisma.driverProfile.findFirst({
      where: { id, tenantId, isActive: true, user: { isActive: true } },
    });
    if (!found) throw new AppError(404, 'NOT_FOUND', 'Driver profile not found or inactive');
  }

  private async assertSupervisorProfile(tenantId: string, id: string) {
    const found = await this.prisma.supervisorProfile.findFirst({
      where: { id, tenantId, isActive: true, user: { isActive: true } },
    });
    if (!found) throw new AppError(404, 'NOT_FOUND', 'Supervisor profile not found or inactive');
  }

  private async assertRoute(tenantId: string, id: string) {
    const found = await this.prisma.route.findFirst({
      where: { id, tenantId, isActive: true },
      select: { id: true, branchId: true },
    });
    if (!found) throw new AppError(404, 'NOT_FOUND', 'Route not found or inactive');
    return found;
  }

  private async assertBranch(tenantId: string, id: string) {
    const found = await this.prisma.branch.findFirst({ where: { id, tenantId, isActive: true } });
    if (!found) throw new AppError(404, 'NOT_FOUND', 'Branch not found or inactive');
  }

  private async assertBus(tenantId: string, id: string) {
    const found = await this.prisma.bus.findFirst({ where: { id, tenantId, isActive: true } });
    if (!found) throw new AppError(404, 'NOT_FOUND', 'Bus not found or inactive');
  }
}
