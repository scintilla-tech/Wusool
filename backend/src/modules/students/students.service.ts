import type { Prisma, PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { hashPassword } from '../../utils/password';
import { toPrismaPagination, type Paginated } from '../../utils/pagination';
import type { StudentCreateInput, StudentUpdateInput } from './students.schemas';

const studentBaseSelect = {
  id: true,
  firstName: true,
  lastName: true,
  email: true,
  phone: true,
  isActive: true,
} satisfies Prisma.UserSelect;

// List queries must NOT retrieve sensitive home coordinates.
const studentListSelect = {
  ...studentBaseSelect,
  studentProfile: { select: { studentId: true } },
} satisfies Prisma.UserSelect;

const studentDetailSelect = {
  ...studentBaseSelect,
  studentProfile: { select: { studentId: true, homeLatitude: true, homeLongitude: true } },
} satisfies Prisma.UserSelect;

type StudentListUser = Prisma.UserGetPayload<{ select: typeof studentListSelect }>;
type StudentDetailUser = Prisma.UserGetPayload<{ select: typeof studentDetailSelect }>;

interface StudentListDto {
  id: string;
  firstName: string;
  lastName: string;
  email: string | null;
  phone: string;
  isActive: boolean;
  studentId: string | null;
}

interface StudentDetailDto extends StudentListDto {
  homeLatitude: number | null;
  homeLongitude: number | null;
}

function toListDto(user: StudentListUser): StudentListDto {
  return {
    id: user.id,
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    phone: user.phone,
    isActive: user.isActive,
    studentId: user.studentProfile?.studentId ?? null,
  };
}

function toDetailDto(user: StudentDetailUser): StudentDetailDto {
  return {
    ...toListDto(user),
    homeLatitude: user.studentProfile?.homeLatitude ?? null,
    homeLongitude: user.studentProfile?.homeLongitude ?? null,
  };
}

export class StudentsService {
  constructor(private readonly prisma: PrismaClient) {}

  async list(tenantId: string, page: number, limit: number): Promise<Paginated<StudentListDto>> {
    const where = { tenantId, role: 'STUDENT' as const };
    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        ...toPrismaPagination(page, limit),
        orderBy: { createdAt: 'desc' },
        select: studentListSelect,
      }),
      this.prisma.user.count({ where }),
    ]);
    return { items: users.map(toListDto), page, limit, total };
  }

  async get(tenantId: string, id: string): Promise<StudentDetailDto> {
    return toDetailDto(await this.findStudent(tenantId, id));
  }

  async create(tenantId: string, input: StudentCreateInput): Promise<StudentDetailDto> {
    const passwordHash = await hashPassword(input.password);

    const user = await this.prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: {
          tenantId,
          role: 'STUDENT',
          firstName: input.firstName,
          lastName: input.lastName,
          email: input.email ?? null,
          phone: input.phone,
          passwordHash,
        },
      });
      await tx.studentProfile.create({
        data: {
          userId: created.id,
          tenantId,
          studentId: input.studentId,
          homeLatitude: input.homeLatitude ?? null,
          homeLongitude: input.homeLongitude ?? null,
        },
      });
      return tx.user.findUniqueOrThrow({
        where: { id: created.id },
        select: studentDetailSelect,
      });
    });

    return toDetailDto(user);
  }

  async update(tenantId: string, id: string, input: StudentUpdateInput): Promise<StudentDetailDto> {
    await this.findStudent(tenantId, id);
    const { firstName, lastName, phone, email, homeLatitude, homeLongitude } = input;

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
      if (homeLatitude !== undefined || homeLongitude !== undefined) {
        await tx.studentProfile.update({
          where: { userId: id },
          data: {
            ...(homeLatitude !== undefined ? { homeLatitude } : {}),
            ...(homeLongitude !== undefined ? { homeLongitude } : {}),
          },
        });
      }
    });

    return toDetailDto(await this.findStudent(tenantId, id));
  }

  async deactivate(tenantId: string, id: string): Promise<void> {
    await this.findStudent(tenantId, id);
    await this.prisma.user.update({ where: { id }, data: { isActive: false } });
  }

  private async findStudent(tenantId: string, id: string): Promise<StudentDetailUser> {
    const user = await this.prisma.user.findFirst({
      where: { id, tenantId, role: 'STUDENT' },
      select: studentDetailSelect,
    });
    if (!user) throw new AppError(404, 'NOT_FOUND', 'Student not found');
    return user;
  }
}
