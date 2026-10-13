import { Prisma, type PrismaClient, type Role } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { attendanceOperationalDate, attendanceOpensAt, dateOnly } from '../../utils/date';
import type { TripEventBus } from '../trips/trip-events';
import type { AttendanceDirection, SetAttendanceIntentInput } from './attendance.schemas';

const MAX_TRANSACTION_RETRIES = 3;

function finishMinutes(value: string | null | undefined): number | null | undefined {
  if (value === undefined) return undefined;
  if (value === null) return null;
  const [hours, minutes] = value.split(':').map(Number);
  return hours * 60 + minutes;
}

function finishTime(value: number | null): string | null {
  if (value === null) return null;
  return `${String(Math.floor(value / 60)).padStart(2, '0')}:${String(value % 60).padStart(2, '0')}`;
}

function isRetryable(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2034';
}

export class AttendanceService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly events?: TripEventBus,
  ) {}

  async getTodayForUser(tenantId: string, userId: string, now = new Date()) {
    const profile = await this.resolveProfile(tenantId, userId);
    const assignment = await this.resolveAssignment(tenantId, profile.id);
    const sessions = await Promise.all(
      (['OUTBOUND', 'RETURN'] as const).map(async (direction) => {
        const operationalDate = attendanceOperationalDate(direction, now);
        const session = await this.ensureSession(
          tenantId,
          assignment.routeId,
          operationalDate,
          direction,
        );
        const record = await this.prisma.attendanceIntent.findUnique({
          where: {
            attendanceSessionId_studentProfileId: {
              attendanceSessionId: session.id,
              studentProfileId: profile.id,
            },
          },
        });
        return this.sessionView(session, record, now);
      }),
    );
    return { sessions };
  }

  async setIntentForUser(
    tenantId: string,
    userId: string,
    direction: AttendanceDirection,
    input: SetAttendanceIntentInput,
    now = new Date(),
  ) {
    if (direction === 'RETURN' && input.expectedFinishTime !== undefined) {
      throw new AppError(
        422,
        'FINISH_TIME_OUTBOUND_ONLY',
        'Expected finish time is available only for outbound attendance',
      );
    }
    const profile = await this.resolveProfile(tenantId, userId);
    const assignment = await this.resolveAssignment(tenantId, profile.id);
    const operationalDate = attendanceOperationalDate(direction, now);
    const session = await this.ensureSession(
      tenantId,
      assignment.routeId,
      operationalDate,
      direction,
    );
    const result = await this.writeIntent({
      tenantId,
      sessionId: session.id,
      studentProfileId: profile.id,
      operationalDate,
      direction,
      intent: input.intent,
      note: input.note,
      expectedFinishMinutes: finishMinutes(input.expectedFinishTime),
      actorUserId: userId,
      actorRole: 'STUDENT',
      source: 'STUDENT_SELF_REGISTRATION',
      now,
    });
    this.events?.emitAttendanceChanged({
      tenantId,
      tripId: session.dailyTripId,
      attendanceSessionId: session.id,
      direction,
      studentProfileId: profile.id,
      studentUserId: userId,
      intent: input.intent,
    });
    return result;
  }

  async setIntentByDriver(
    tenantId: string,
    driverUserId: string,
    tripId: string,
    studentProfileId: string,
    input: SetAttendanceIntentInput,
    now = new Date(),
  ) {
    const trip = await this.resolveDriverTrip(tenantId, driverUserId, tripId);
    if (!trip.routeId || !['SCHEDULED', 'IN_PROGRESS'].includes(trip.status)) {
      throw new AppError(409, 'INVALID_STATE', 'Trip is not active');
    }
    const member = await this.prisma.tripStudent.findFirst({
      where: { tenantId, dailyTripId: trip.id, studentProfileId },
      select: { id: true, studentProfile: { select: { userId: true } } },
    });
    if (!member)
      throw new AppError(404, 'STUDENT_NOT_IN_TRIP', 'Student is not assigned to this trip');
    if (trip.direction === 'RETURN' && input.expectedFinishTime !== undefined) {
      throw new AppError(422, 'FINISH_TIME_OUTBOUND_ONLY', 'Finish time is outbound-only');
    }
    const session = await this.ensureSession(
      tenantId,
      trip.routeId,
      dateOnly(trip.tripDate),
      trip.direction,
      trip.id,
    );
    const result = await this.writeIntent({
      tenantId,
      sessionId: session.id,
      studentProfileId,
      operationalDate: dateOnly(trip.tripDate),
      direction: trip.direction,
      intent: input.intent,
      note: input.note,
      expectedFinishMinutes: finishMinutes(input.expectedFinishTime),
      actorUserId: driverUserId,
      actorRole: 'DRIVER',
      source: 'DRIVER_ASSISTED_REGISTRATION',
      now,
    });
    this.events?.emitAttendanceChanged({
      tenantId,
      tripId: trip.id,
      attendanceSessionId: session.id,
      direction: trip.direction,
      studentProfileId,
      studentUserId: member.studentProfile.userId,
      intent: input.intent,
    });
    return result;
  }

  async closeByDriver(tenantId: string, driverUserId: string, tripId: string, now = new Date()) {
    const trip = await this.resolveDriverTrip(tenantId, driverUserId, tripId);
    if (!trip.routeId || !['SCHEDULED', 'IN_PROGRESS'].includes(trip.status)) {
      throw new AppError(409, 'INVALID_STATE', 'Trip is not active');
    }
    const session = await this.ensureSession(
      tenantId,
      trip.routeId,
      dateOnly(trip.tripDate),
      trip.direction,
      trip.id,
    );
    const opensAt = attendanceOpensAt(trip.direction, dateOnly(trip.tripDate));
    if (now < opensAt) throw new AppError(422, 'ATTENDANCE_NOT_OPEN', 'Attendance is not open yet');

    const result = await this.withSerializableRetry(async (tx) => {
      const changed = await tx.attendanceSession.updateMany({
        where: { id: session.id, tenantId, status: 'OPEN', dailyTripId: trip.id },
        data: { status: 'CLOSED', closedAt: now, closedByDriverProfileId: trip.driverProfileId },
      });
      if (changed.count !== 1) {
        throw new AppError(409, 'ATTENDANCE_ALREADY_CLOSED', 'Attendance is already closed');
      }
      const [attending, absent, roster] = await Promise.all([
        tx.attendanceIntent.count({
          where: { attendanceSessionId: session.id, intent: 'ATTENDING' },
        }),
        tx.attendanceIntent.count({ where: { attendanceSessionId: session.id, intent: 'ABSENT' } }),
        tx.tripStudent.findMany({
          where: { tenantId, dailyTripId: trip.id },
          select: { studentProfile: { select: { userId: true } } },
        }),
      ]);
      const supervisorUserIds = trip.busId
        ? await tx.supervisorBusAssignment.findMany({
            where: { tenantId, busId: trip.busId, isActive: true },
            select: { supervisorProfile: { select: { userId: true } } },
          })
        : [];
      const userIds = new Set([
        ...roster.map((row) => row.studentProfile.userId),
        ...supervisorUserIds.map((row) => row.supervisorProfile.userId),
      ]);
      if (userIds.size > 0) {
        await tx.notification.createMany({
          data: [...userIds].map((userId) => ({
            tenantId,
            userId,
            type: 'ATTENDANCE_CLOSED',
            title: 'اكتمل التحضير',
            body: trip.direction === 'OUTBOUND' ? 'تم إغلاق تحضير الذهاب' : 'تم إغلاق تحضير العودة',
            data: { tripId: trip.id, attendanceSessionId: session.id, direction: trip.direction },
          })),
        });
      }
      await tx.auditLog.create({
        data: {
          tenantId,
          actorUserId: driverUserId,
          action: 'ATTENDANCE_SESSION_CLOSED',
          entityType: 'AttendanceSession',
          entityId: session.id,
          metadata: { tripId: trip.id, direction: trip.direction, attending, absent },
        },
      });
      return { ...session, status: 'CLOSED' as const, closedAt: now, attending, absent };
    });
    this.events?.emitAttendanceClosed({
      tenantId,
      tripId: trip.id,
      attendanceSessionId: session.id,
      direction: trip.direction,
      closedAt: now.toISOString(),
    });
    return result;
  }

  private async writeIntent(args: {
    tenantId: string;
    sessionId: string;
    studentProfileId: string;
    operationalDate: Date;
    direction: AttendanceDirection;
    intent: 'ATTENDING' | 'ABSENT';
    note?: string | null;
    expectedFinishMinutes?: number | null;
    actorUserId: string;
    actorRole: Role;
    source: 'STUDENT_SELF_REGISTRATION' | 'DRIVER_ASSISTED_REGISTRATION';
    now: Date;
  }) {
    const opensAt = attendanceOpensAt(args.direction, args.operationalDate);
    if (args.now < opensAt)
      throw new AppError(422, 'ATTENDANCE_NOT_OPEN', 'Attendance is not open yet');

    return this.withSerializableRetry(async (tx) => {
      // The conditional write takes a row lock. A concurrent close either wins
      // first or causes this serializable transaction to retry against CLOSED.
      const open = await tx.attendanceSession.updateMany({
        where: { id: args.sessionId, tenantId: args.tenantId, status: 'OPEN' },
        data: { updatedAt: args.now },
      });
      if (open.count !== 1) throw new AppError(409, 'ATTENDANCE_CLOSED', 'Attendance is closed');
      const previous = await tx.attendanceIntent.findUnique({
        where: {
          attendanceSessionId_studentProfileId: {
            attendanceSessionId: args.sessionId,
            studentProfileId: args.studentProfileId,
          },
        },
        select: { intent: true, expectedFinishMinutes: true },
      });
      const expected =
        args.expectedFinishMinutes === undefined
          ? (previous?.expectedFinishMinutes ?? null)
          : args.expectedFinishMinutes;
      const record = await tx.attendanceIntent.upsert({
        where: {
          attendanceSessionId_studentProfileId: {
            attendanceSessionId: args.sessionId,
            studentProfileId: args.studentProfileId,
          },
        },
        update: {
          intent: args.intent,
          note: args.note === undefined ? undefined : args.note,
          expectedFinishMinutes: expected,
          source: args.source,
          actorUserId: args.actorUserId,
          actorRole: args.actorRole,
        },
        create: {
          tenantId: args.tenantId,
          attendanceSessionId: args.sessionId,
          studentProfileId: args.studentProfileId,
          operationalDate: args.operationalDate,
          direction: args.direction,
          intent: args.intent,
          note: args.note ?? null,
          expectedFinishMinutes: expected,
          source: args.source,
          actorUserId: args.actorUserId,
          actorRole: args.actorRole,
        },
      });
      await tx.attendanceAudit.create({
        data: {
          tenantId: args.tenantId,
          attendanceSessionId: args.sessionId,
          studentProfileId: args.studentProfileId,
          previousStatus: previous?.intent ?? null,
          attendanceStatus: args.intent,
          source: args.source,
          actorUserId: args.actorUserId,
          actorRole: args.actorRole,
          expectedFinishMinutes: expected,
        },
      });
      return { ...record, expectedFinishTime: finishTime(record.expectedFinishMinutes) };
    });
  }

  private async ensureSession(
    tenantId: string,
    routeId: string,
    operationalDate: Date,
    direction: AttendanceDirection,
    dailyTripId?: string,
  ) {
    const trip = dailyTripId
      ? { id: dailyTripId }
      : await this.prisma.dailyTrip.findFirst({
          where: {
            tenantId,
            routeId,
            tripDate: operationalDate,
            direction,
            status: { not: 'CANCELLED' },
          },
          select: { id: true },
        });
    return this.prisma.attendanceSession.upsert({
      where: {
        tenantId_routeId_operationalDate_direction: {
          tenantId,
          routeId,
          operationalDate,
          direction,
        },
      },
      update: trip ? { dailyTripId: trip.id } : {},
      create: { tenantId, routeId, operationalDate, direction, dailyTripId: trip?.id },
    });
  }

  private sessionView(
    session: {
      id: string;
      dailyTripId: string | null;
      operationalDate: Date;
      direction: AttendanceDirection;
      status: 'OPEN' | 'CLOSED';
      closedAt: Date | null;
    },
    record: { intent: string; expectedFinishMinutes: number | null; source: string } | null,
    now: Date,
  ) {
    const opensAt = attendanceOpensAt(session.direction, session.operationalDate);
    return {
      id: session.id,
      tripId: session.dailyTripId,
      operationalDate: session.operationalDate,
      direction: session.direction,
      status: session.status,
      opensAt,
      isOpen: session.status === 'OPEN' && now >= opensAt,
      closedAt: session.closedAt,
      intent: record?.intent ?? null,
      source: record?.source ?? null,
      expectedFinishTime: finishTime(record?.expectedFinishMinutes ?? null),
    };
  }

  private async resolveProfile(tenantId: string, userId: string) {
    const profile = await this.prisma.studentProfile.findFirst({
      where: { userId, tenantId, isActive: true },
      select: { id: true },
    });
    if (!profile) throw new AppError(404, 'NOT_FOUND', 'Student profile not found');
    return profile;
  }

  private async resolveAssignment(tenantId: string, studentProfileId: string) {
    const assignment = await this.prisma.studentAssignment.findFirst({
      where: { tenantId, studentProfileId, isActive: true, routeId: { not: null } },
      orderBy: { assignedAt: 'desc' },
      select: { routeId: true },
    });
    if (!assignment?.routeId)
      throw new AppError(404, 'NO_ACTIVE_ROUTE', 'No active route assignment');
    return { routeId: assignment.routeId };
  }

  private async resolveDriverTrip(tenantId: string, userId: string, tripId: string) {
    const profile = await this.prisma.driverProfile.findFirst({
      where: { tenantId, userId, isActive: true },
      select: { id: true },
    });
    if (!profile) throw new AppError(404, 'NOT_FOUND', 'Driver profile not found');
    const trip = await this.prisma.dailyTrip.findFirst({
      where: { id: tripId, tenantId, driverProfileId: profile.id },
      select: {
        id: true,
        tenantId: true,
        routeId: true,
        busId: true,
        driverProfileId: true,
        tripDate: true,
        direction: true,
        status: true,
      },
    });
    if (!trip) throw new AppError(404, 'NOT_FOUND', 'Trip not found');
    return trip;
  }

  private async withSerializableRetry<T>(work: (tx: Prisma.TransactionClient) => Promise<T>) {
    for (let attempt = 1; attempt <= MAX_TRANSACTION_RETRIES; attempt += 1) {
      try {
        return await this.prisma.$transaction(work, {
          isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
        });
      } catch (error) {
        if (!isRetryable(error) || attempt === MAX_TRANSACTION_RETRIES) throw error;
      }
    }
    throw new AppError(409, 'CONCURRENT_UPDATE', 'Concurrent attendance update; retry');
  }
}
