import type { PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { hashPassword } from '../../utils/password';
import type { TenantCreateInput, TenantUpdateInput } from './platform.schemas';

export class PlatformService {
  constructor(private readonly prisma: PrismaClient) {}

  async listTenants() {
    return this.prisma.tenant.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        code: true,
        name: true,
        isActive: true,
        createdAt: true,
        _count: { select: { users: true, buses: true } },
      },
    });
  }

  async createTenant(input: TenantCreateInput) {
    return this.prisma.$transaction(async (tx) => {
      const tenant = await tx.tenant.create({ data: { code: input.code, name: input.name } });
      if (input.admin) {
        const passwordHash = await hashPassword(input.admin.password);
        await tx.user.create({
          data: {
            tenantId: tenant.id,
            role: 'UNIVERSITY_ADMIN',
            firstName: input.admin.firstName,
            lastName: input.admin.lastName,
            phone: input.admin.phone,
            passwordHash,
          },
        });
      }
      return tenant;
    });
  }

  async updateTenant(id: string, input: TenantUpdateInput) {
    const tenant = await this.prisma.tenant.findUnique({ where: { id } });
    if (!tenant) throw new AppError(404, 'NOT_FOUND', 'Tenant not found');
    return this.prisma.tenant.update({ where: { id }, data: input });
  }
}
