import type { PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';

function startOfToday(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

function isPastCutoff(cutoff: string, now: Date): boolean {
  const [h, m] = cutoff.split(':').map(Number);
  const cutoffDate = new Date(now);
  cutoffDate.setHours(h, m, 0, 0);
  return now.getTime() >= cutoffDate.getTime();
}

export class AttendanceService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly cutoff: string,
  ) {}

  async setIntentForUser(
    tenantId: string,
    userId: string,
    intent: 'ATTENDING' | 'ABSENT',
    note?: string,
  ) {
    const profile = await this.resolveProfile(tenantId, userId);
    return this.setIntent(tenantId, profile.id, intent, note);
  }

  async getTodayForUser(tenantId: string, userId: string) {
    const profile = await this.resolveProfile(tenantId, userId);
    return this.prisma.attendanceIntent.findUnique({
      where: {
        studentProfileId_tripDate: { studentProfileId: profile.id, tripDate: startOfToday() },
      },
    });
  }

  private async setIntent(
    tenantId: string,
    studentProfileId: string,
    intent: 'ATTENDING' | 'ABSENT',
    note?: string,
  ) {
    if (isPastCutoff(this.cutoff, new Date())) {
      throw new AppError(422, 'CUTOFF_PASSED', 'Attendance cutoff has passed for today');
    }
    const tripDate = startOfToday();
    return this.prisma.attendanceIntent.upsert({
      where: { studentProfileId_tripDate: { studentProfileId, tripDate } },
      update: { intent, note: note ?? null },
      create: { tenantId, studentProfileId, tripDate, intent, note: note ?? null },
    });
  }

  private async resolveProfile(tenantId: string, userId: string) {
    const profile = await this.prisma.studentProfile.findFirst({
      where: { userId, tenantId, isActive: true },
    });
    if (!profile) throw new AppError(404, 'NOT_FOUND', 'Student profile not found');
    return profile;
  }
}
