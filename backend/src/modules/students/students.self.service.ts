import type { PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { hashPassword } from '../../utils/password';
import { OtpService } from '../otp/otp.service';
import type { ProfileUpdateInput, RegisterInput } from './students.self.schemas';

export interface StudentSelfDto {
  id: string;
  tenantId: string | null;
  firstName: string;
  lastName: string;
  email: string | null;
  phone: string;
  studentId: string | null;
  homeLatitude: number | null;
  homeLongitude: number | null;
  isActive: boolean;
}

export class StudentSelfService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly otp: OtpService,
    private readonly isDevelopment: boolean,
  ) {}

  async register(input: RegisterInput): Promise<{ userId: string; devOtp?: string }> {
    const tenant = await this.prisma.tenant.findUnique({ where: { code: input.tenantCode } });
    if (!tenant || !tenant.isActive) {
      throw new AppError(404, 'TENANT_NOT_FOUND', 'University not found');
    }

    const passwordHash = await hashPassword(input.password);

    const user = await this.prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: {
          tenantId: tenant.id,
          role: 'STUDENT',
          firstName: input.firstName,
          lastName: input.lastName,
          email: input.email ?? null,
          phone: input.phone,
          passwordHash,
          isActive: false,
        },
      });
      await tx.studentProfile.create({
        data: {
          userId: created.id,
          tenantId: tenant.id,
          studentId: input.studentId,
          homeLatitude: input.homeLatitude ?? null,
          homeLongitude: input.homeLongitude ?? null,
        },
      });
      return created;
    });

    const code = await this.otp.generate(input.phone);

    return { userId: user.id, ...(this.isDevelopment ? { devOtp: code } : {}) };
  }

  async verify(userId: string, code: string): Promise<void> {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, role: 'STUDENT' },
      include: { studentProfile: true },
    });
    if (!user) {
      throw new AppError(404, 'NOT_FOUND', 'Registration not found');
    }
    if (user.isActive) {
      return; // already verified
    }

    const valid = this.otp.verify(user.phone, code);
    if (!valid) {
      throw new AppError(400, 'INVALID_CODE', 'Invalid or expired verification code');
    }

    await this.prisma.user.update({ where: { id: user.id }, data: { isActive: true } });
  }

  async getMe(userId: string): Promise<StudentSelfDto> {
    const user = await this.findStudent(userId);
    return toDto(user);
  }

  async updateMe(userId: string, input: ProfileUpdateInput): Promise<StudentSelfDto> {
    const user = await this.findStudent(userId);

    await this.prisma.$transaction(async (tx) => {
      if (input.phone !== undefined || input.email !== undefined) {
        await tx.user.update({
          where: { id: user.id },
          data: {
            ...(input.phone !== undefined ? { phone: input.phone } : {}),
            ...(input.email !== undefined ? { email: input.email } : {}),
          },
        });
      }
      if (input.homeLatitude !== undefined || input.homeLongitude !== undefined) {
        await tx.studentProfile.update({
          where: { userId: user.id },
          data: {
            ...(input.homeLatitude !== undefined ? { homeLatitude: input.homeLatitude } : {}),
            ...(input.homeLongitude !== undefined ? { homeLongitude: input.homeLongitude } : {}),
          },
        });
      }
    });

    return toDto(await this.findStudent(userId));
  }

  private async findStudent(userId: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, role: 'STUDENT' },
      include: { studentProfile: true },
    });
    if (!user || !user.isActive) {
      throw new AppError(404, 'NOT_FOUND', 'Student not found');
    }
    return user;
  }
}

function toDto(user: {
  id: string;
  tenantId: string | null;
  firstName: string;
  lastName: string;
  email: string | null;
  phone: string;
  isActive: boolean;
  studentProfile: {
    studentId: string;
    homeLatitude: number | null;
    homeLongitude: number | null;
  } | null;
}): StudentSelfDto {
  return {
    id: user.id,
    tenantId: user.tenantId,
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    phone: user.phone,
    studentId: user.studentProfile?.studentId ?? null,
    homeLatitude: user.studentProfile?.homeLatitude ?? null,
    homeLongitude: user.studentProfile?.homeLongitude ?? null,
    isActive: user.isActive,
  };
}
