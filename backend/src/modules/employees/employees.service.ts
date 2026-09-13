import type { Prisma, PrismaClient, Role } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { hashPassword } from '../../utils/password';
import { toPrismaPagination, type Paginated } from '../../utils/pagination';
import type { EmployeeCreateInput, EmployeeUpdateInput } from './employees.schemas';

const employeeSelect = {
  id: true,
  role: true,
  firstName: true,
  lastName: true,
  email: true,
  phone: true,
  isActive: true,
  driverProfile: {
    select: {
      employeeId: true,
      nationality: true,
      joinDate: true,
      iqamaExpiry: true,
      employmentStatus: true,
      licenseNumber: true,
    },
  },
  supervisorProfile: {
    select: {
      employeeId: true,
      nationality: true,
      joinDate: true,
      iqamaExpiry: true,
      employmentStatus: true,
    },
  },
  fieldSupervisorProfile: {
    select: {
      employeeId: true,
      nationality: true,
      joinDate: true,
      iqamaExpiry: true,
      employmentStatus: true,
    },
  },
} satisfies Prisma.UserSelect;

type EmployeeUser = Prisma.UserGetPayload<{ select: typeof employeeSelect }>;

const EMPLOYEE_ROLES: Role[] = ['DRIVER', 'SUPERVISOR', 'FIELD_SUPERVISOR'];

export interface EmployeeDto {
  id: string;
  role: Role;
  firstName: string;
  lastName: string;
  email: string | null;
  phone: string;
  isActive: boolean;
  employeeId: string | null;
  nationality: string | null;
  joinDate: Date | null;
  iqamaExpiry: Date | null;
  employmentStatus: string | null;
  licenseNumber: string | null;
}

export function toEmployeeDto(user: EmployeeUser): EmployeeDto {
  const driver = user.driverProfile;
  const supervisor = user.supervisorProfile;
  const field = user.fieldSupervisorProfile;
  const profile = driver ?? supervisor ?? field;
  return {
    id: user.id,
    role: user.role,
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    phone: user.phone,
    isActive: user.isActive,
    employeeId: profile?.employeeId ?? null,
    nationality: profile?.nationality ?? null,
    joinDate: profile?.joinDate ?? null,
    iqamaExpiry: profile?.iqamaExpiry ?? null,
    employmentStatus: profile?.employmentStatus ?? null,
    licenseNumber: driver?.licenseNumber ?? null,
  };
}

export class EmployeesService {
  constructor(private readonly prisma: PrismaClient) {}

  async list(
    tenantId: string,
    role: Role,
    page: number,
    limit: number,
  ): Promise<Paginated<EmployeeDto>> {
    if (!EMPLOYEE_ROLES.includes(role)) {
      throw new AppError(400, 'INVALID_ROLE', 'Invalid employee role');
    }
    const where = { tenantId, role };
    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        ...toPrismaPagination(page, limit),
        orderBy: { createdAt: 'desc' },
        select: employeeSelect,
      }),
      this.prisma.user.count({ where }),
    ]);
    return { items: users.map(toEmployeeDto), page, limit, total };
  }

  async get(tenantId: string, id: string): Promise<EmployeeDto> {
    const user = await this.findEmployee(tenantId, id);
    return toEmployeeDto(user);
  }

  async create(tenantId: string, input: EmployeeCreateInput): Promise<EmployeeDto> {
    const passwordHash = await hashPassword(input.password);

    const user = await this.prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: {
          tenantId,
          role: input.role,
          firstName: input.firstName,
          lastName: input.lastName,
          email: input.email ?? null,
          phone: input.phone,
          passwordHash,
        },
      });

      const profileData = {
        userId: created.id,
        tenantId,
        employeeId: input.employeeId,
        nationalIdOrIqama: input.nationalIdOrIqama ?? null,
        nationality: input.nationality ?? null,
        joinDate: input.joinDate ?? null,
        iqamaExpiry: input.iqamaExpiry ?? null,
        employmentStatus: input.employmentStatus,
      };

      if (input.role === 'DRIVER') {
        await tx.driverProfile.create({ data: profileData });
      } else if (input.role === 'SUPERVISOR') {
        await tx.supervisorProfile.create({ data: profileData });
      } else {
        await tx.fieldSupervisorProfile.create({ data: profileData });
      }

      return tx.user.findUniqueOrThrow({
        where: { id: created.id },
        select: employeeSelect,
      });
    });

    return toEmployeeDto(user);
  }

  async update(tenantId: string, id: string, input: EmployeeUpdateInput): Promise<EmployeeDto> {
    const existing = await this.findEmployee(tenantId, id);
    const {
      firstName,
      lastName,
      phone,
      email,
      employeeId,
      nationalIdOrIqama,
      nationality,
      joinDate,
      iqamaExpiry,
      employmentStatus,
    } = input;

    await this.prisma.$transaction(async (tx) => {
      if (
        firstName !== undefined ||
        lastName !== undefined ||
        phone !== undefined ||
        email !== undefined
      ) {
        await tx.user.update({
          where: { id },
          data: {
            ...(firstName !== undefined ? { firstName } : {}),
            ...(lastName !== undefined ? { lastName } : {}),
            ...(phone !== undefined ? { phone } : {}),
            ...(email !== undefined ? { email } : {}),
          },
        });
      }

      const profileData = {
        ...(employeeId !== undefined ? { employeeId } : {}),
        ...(nationalIdOrIqama !== undefined ? { nationalIdOrIqama } : {}),
        ...(nationality !== undefined ? { nationality } : {}),
        ...(joinDate !== undefined ? { joinDate } : {}),
        ...(iqamaExpiry !== undefined ? { iqamaExpiry } : {}),
        ...(employmentStatus !== undefined ? { employmentStatus } : {}),
      };

      if (Object.keys(profileData).length > 0) {
        await this.updateProfile(tx, existing.role, id, profileData);
      }
    });

    const user = await this.findEmployee(tenantId, id);
    return toEmployeeDto(user);
  }

  async deactivate(tenantId: string, id: string): Promise<void> {
    await this.findEmployee(tenantId, id);
    await this.prisma.user.update({ where: { id }, data: { isActive: false } });
  }

  private async findEmployee(tenantId: string, id: string): Promise<EmployeeUser> {
    const user = await this.prisma.user.findFirst({
      where: { id, tenantId, role: { in: EMPLOYEE_ROLES } },
      select: employeeSelect,
    });
    if (!user) throw new AppError(404, 'NOT_FOUND', 'Employee not found');
    return user;
  }

  private updateProfile(
    tx: Prisma.TransactionClient,
    role: Role,
    userId: string,
    data: Prisma.DriverProfileUncheckedUpdateInput,
  ) {
    if (role === 'DRIVER') {
      return tx.driverProfile.update({ where: { userId }, data });
    }
    if (role === 'SUPERVISOR') {
      return tx.supervisorProfile.update({ where: { userId }, data });
    }
    return tx.fieldSupervisorProfile.update({ where: { userId }, data });
  }
}
