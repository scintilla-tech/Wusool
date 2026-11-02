import { Prisma, type PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { dateOnly } from '../../utils/date';
import type { TripCreateInput } from './trips.schemas';
import type { TripEventBus } from './trip-events';

function isUniqueViolation(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}

export class TripService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly events?: TripEventBus,
  ) {}

  // ----- Admin: create a daily trip and populate its student list -----
  async createTrip(tenantId: string, input: TripCreateInput) {
    const direction = input.direction ?? 'OUTBOUND';
    await this.assertRoute(tenantId, input.routeId);
    await this.assertBus(tenantId, input.busId);
    await this.assertDriverProfile(tenantId, input.driverProfileId);
    await this.assertDriverAssignedToBus(tenantId, input.driverProfileId, input.busId);

    const tripDate = dateOnly(input.tripDate);

    const conflict = await this.prisma.dailyTrip.findFirst({
      where: {
        tenantId,
        tripDate,
        status: { in: ['SCHEDULED', 'IN_PROGRESS'] },
        direction,
        OR: [{ busId: input.busId }, { driverProfileId: input.driverProfileId }],
      },
      select: { id: true },
    });
    if (conflict) {
      throw new AppError(
        409,
        'TRIP_CONFLICT',
        'The bus or driver already has an active trip for this date',
      );
    }

    // Keep the complete assigned roster. Attendance intent is independent and
    // may be supplied by the student or assisted by the driver until closure.
    const assignments = await this.prisma.studentAssignment.findMany({
      where: { tenantId, routeId: input.routeId, isActive: true },
      select: { studentProfileId: true },
    });
    const profileIds = assignments.map((a) => a.studentProfileId);

    return this.prisma.$transaction(async (tx) => {
      const trip = await tx.dailyTrip.create({
        data: {
          tenantId,
          routeId: input.routeId,
          busId: input.busId,
          driverProfileId: input.driverProfileId,
          tripDate,
          direction,
          status: 'SCHEDULED',
        },
      });
      await tx.attendanceSession.upsert({
        where: {
          tenantId_routeId_operationalDate_direction: {
            tenantId,
            routeId: input.routeId,
            operationalDate: tripDate,
            direction,
          },
        },
        update: { dailyTripId: trip.id },
        create: {
          tenantId,
          routeId: input.routeId,
          operationalDate: tripDate,
          direction,
          dailyTripId: trip.id,
        },
      });
      if (profileIds.length > 0) {
        await tx.tripStudent.createMany({
          data: profileIds.map((studentProfileId) => ({
            tenantId,
            dailyTripId: trip.id,
            studentProfileId,
            status: 'WAITING',
          })),
        });
      }
      return tx.dailyTrip.findUniqueOrThrow({
        where: { id: trip.id },
        include: { tripStudents: { include: { studentProfile: true } }, bus: true, route: true },
      });
    });
  }

  async listTrips(tenantId: string) {
    return this.prisma.dailyTrip.findMany({
      where: { tenantId },
      orderBy: { tripDate: 'desc' },
      include: { bus: true, route: true },
      take: 100,
    });
  }

  // ----- Driver: today's trip -----
  async getDriverToday(tenantId: string, driverUserId: string) {
    const trips = await this.getDriverTodayTrips(tenantId, driverUserId);
    return trips[0] ?? null;
  }

  async getDriverTodayTrips(tenantId: string, driverUserId: string) {
    const profile = await this.resolveDriverProfile(tenantId, driverUserId);
    const today = dateOnly(new Date());
    return this.prisma.dailyTrip.findMany({
      where: {
        tenantId,
        driverProfileId: profile.id,
        tripDate: today,
        status: { in: ['SCHEDULED', 'IN_PROGRESS'] },
      },
      include: {
        bus: true,
        route: {
          include: {
            routeNeighborhoods: {
              orderBy: { sequenceOrder: 'asc' },
              include: { neighborhood: true },
            },
          },
        },
        tripStudents: {
          include: {
            studentProfile: {
              select: {
                id: true,
                studentId: true,
                userId: true,
                homeLatitude: true,
                homeLongitude: true,
                user: { select: { id: true, firstName: true, lastName: true, phone: true } },
              },
            },
          },
          orderBy: { createdAt: 'asc' },
        },
        attendanceSession: {
          include: {
            attendanceIntents: {
              select: {
                studentProfileId: true,
                intent: true,
                source: true,
                expectedFinishMinutes: true,
              },
            },
          },
        },
      },
      orderBy: { direction: 'asc' },
    });
  }

  async startTrip(tenantId: string, driverUserId: string, tripId: string) {
    const trip = await this.assertTripForDriver(tenantId, driverUserId, tripId);
    if (trip.status !== 'SCHEDULED') {
      throw new AppError(409, 'INVALID_STATE', 'Trip is not in SCHEDULED state');
    }
    const today = dateOnly(new Date());
    if (dateOnly(trip.tripDate).getTime() !== today.getTime()) {
      throw new AppError(409, 'INVALID_STATE', "Only today's trip can be started");
    }
    const changed = await this.markTripStarted(tenantId, driverUserId, tripId, trip, today);
    if (changed.count !== 1) {
      throw new AppError(409, 'INVALID_STATE', 'Trip is not in SCHEDULED state');
    }
    return this.prisma.dailyTrip.findUniqueOrThrow({ where: { id: tripId } });
  }

  private async markTripStarted(
    tenantId: string,
    driverUserId: string,
    tripId: string,
    trip: { driverProfileId: string | null },
    today: Date,
  ) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        const result = await tx.dailyTrip.updateMany({
          where: {
            id: tripId,
            tenantId,
            driverProfileId: trip.driverProfileId,
            status: 'SCHEDULED',
            tripDate: today,
          },
          data: { status: 'IN_PROGRESS', startedAt: new Date() },
        });
        if (result.count === 1) {
          await tx.auditLog.create({
            data: {
              tenantId,
              actorUserId: driverUserId,
              action: 'TRIP_STARTED',
              entityType: 'DailyTrip',
              entityId: tripId,
            },
          });
        }
        return result;
      });
    } catch (error) {
      // The partial unique indexes allow one running trip per driver and per bus.
      if (isUniqueViolation(error)) {
        throw new AppError(
          409,
          'TRIP_ALREADY_IN_PROGRESS',
          'The driver or bus already has a trip in progress',
        );
      }
      throw error;
    }
  }

  async setStudentStatus(
    tenantId: string,
    driverUserId: string,
    tripId: string,
    studentProfileId: string,
    status: 'WAITING' | 'BOARDED' | 'NOT_READY' | 'MISSED',
  ) {
    const profile = await this.resolveDriverProfile(tenantId, driverUserId);
    const now = new Date();
    const changed = await this.prisma.tripStudent.updateMany({
      where: {
        dailyTripId: tripId,
        studentProfileId,
        dailyTrip: {
          tenantId,
          driverProfileId: profile.id,
          status: 'IN_PROGRESS',
        },
      },
      data: {
        status,
        boardedAt: status === 'BOARDED' ? now : null,
        missedAt: status === 'MISSED' ? now : null,
        transportConfirmed: false,
      },
    });
    if (changed.count !== 1) {
      throw new AppError(409, 'INVALID_STATE', 'Trip is not in progress');
    }
    return this.prisma.tripStudent.findUniqueOrThrow({
      where: { dailyTripId_studentProfileId: { dailyTripId: tripId, studentProfileId } },
    });
  }

  async completeTrip(tenantId: string, actorUserId: string, tripId: string) {
    const trip = await this.assertTripForDriver(tenantId, actorUserId, tripId);
    if (trip.status !== 'IN_PROGRESS') {
      throw new AppError(409, 'INVALID_STATE', 'Trip is not in progress');
    }
    const completed = await this.finishTrip(tenantId, tripId, 'TRIP_COMPLETED', actorUserId);
    if (!completed) {
      throw new AppError(409, 'INVALID_STATE', 'Trip is not in progress');
    }
    return this.prisma.dailyTrip.findUnique({ where: { id: tripId } });
  }

  async completeTripByGeofence(tenantId: string, tripId: string): Promise<boolean> {
    const trip = await this.prisma.dailyTrip.findFirst({ where: { id: tripId, tenantId } });
    if (!trip) throw new AppError(404, 'NOT_FOUND', 'Trip not found');
    if (trip.status !== 'IN_PROGRESS') return false;
    return this.finishTrip(tenantId, tripId, 'TRIP_AUTO_COMPLETED_BY_GEOFENCE', null);
  }

  private async finishTrip(
    tenantId: string,
    tripId: string,
    action: string,
    actorUserId: string | null,
  ): Promise<boolean> {
    const completed = await this.prisma.$transaction(async (tx) => {
      const changed = await tx.dailyTrip.updateMany({
        where: { id: tripId, tenantId, status: 'IN_PROGRESS' },
        data: { status: 'COMPLETED', completedAt: new Date() },
      });
      if (changed.count !== 1) return false;
      // Only BOARDED students become transport-attendance-confirmed.
      await tx.tripStudent.updateMany({
        where: { dailyTripId: tripId, status: 'BOARDED' },
        data: { transportConfirmed: true },
      });
      await tx.auditLog.create({
        data: { tenantId, actorUserId, action, entityType: 'DailyTrip', entityId: tripId },
      });
      return true;
    });
    if (completed) this.events?.emitCompleted({ tenantId, tripId });
    return completed;
  }

  // ----- Helpers -----
  private async resolveDriverProfile(tenantId: string, userId: string) {
    const profile = await this.prisma.driverProfile.findFirst({
      where: { userId, tenantId, isActive: true },
    });
    if (!profile) throw new AppError(404, 'NOT_FOUND', 'Driver profile not found');
    return profile;
  }

  private async assertTripForDriver(tenantId: string, driverUserId: string, tripId: string) {
    const profile = await this.resolveDriverProfile(tenantId, driverUserId);
    const trip = await this.prisma.dailyTrip.findFirst({
      where: { id: tripId, tenantId, driverProfileId: profile.id },
    });
    if (!trip) throw new AppError(404, 'NOT_FOUND', 'Trip not found');
    return trip;
  }

  private async assertRoute(tenantId: string, id: string) {
    const found = await this.prisma.route.findFirst({ where: { id, tenantId, isActive: true } });
    if (!found) throw new AppError(404, 'NOT_FOUND', 'Route not found or inactive');
  }

  private async assertBus(tenantId: string, id: string) {
    const found = await this.prisma.bus.findFirst({ where: { id, tenantId, isActive: true } });
    if (!found) throw new AppError(404, 'NOT_FOUND', 'Bus not found or inactive');
  }

  private async assertDriverProfile(tenantId: string, id: string) {
    const found = await this.prisma.driverProfile.findFirst({
      where: { id, tenantId, isActive: true },
    });
    if (!found) throw new AppError(404, 'NOT_FOUND', 'Driver profile not found or inactive');
  }

  private async assertDriverAssignedToBus(
    tenantId: string,
    driverProfileId: string,
    busId: string,
  ) {
    const found = await this.prisma.driverAssignment.findFirst({
      where: { tenantId, driverProfileId, busId, isActive: true },
      select: { id: true },
    });
    if (!found) {
      throw new AppError(422, 'DRIVER_BUS_MISMATCH', 'Driver is not actively assigned to this bus');
    }
  }
}
