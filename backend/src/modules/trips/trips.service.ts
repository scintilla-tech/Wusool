import type { Prisma, PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import type { TripCreateInput } from './trips.schemas';

function dateOnly(d: Date): Date {
  const copy = new Date(d);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

export class TripService {
  constructor(private readonly prisma: PrismaClient) {}

  // ----- Admin: create a daily trip and populate its student list -----
  async createTrip(tenantId: string, input: TripCreateInput) {
    await this.assertRoute(tenantId, input.routeId);
    await this.assertBus(tenantId, input.busId);
    await this.assertDriverProfile(tenantId, input.driverProfileId);

    const tripDate = dateOnly(input.tripDate);

    // Students assigned to this route with an ATTENDING intent for the day.
    const assignments = await this.prisma.studentAssignment.findMany({
      where: { tenantId, routeId: input.routeId, isActive: true },
      select: { studentProfileId: true },
    });
    const profileIds = assignments.map((a) => a.studentProfileId);

    const intents = profileIds.length
      ? await this.prisma.attendanceIntent.findMany({
          where: { tenantId, tripDate, intent: 'ATTENDING', studentProfileId: { in: profileIds } },
          select: { studentProfileId: true },
        })
      : [];
    const attendingIds = intents.map((i) => i.studentProfileId);

    return this.prisma.$transaction(async (tx) => {
      const trip = await tx.dailyTrip.create({
        data: {
          tenantId,
          routeId: input.routeId,
          busId: input.busId,
          driverProfileId: input.driverProfileId,
          tripDate,
          status: 'SCHEDULED',
        },
      });
      if (attendingIds.length > 0) {
        await tx.tripStudent.createMany({
          data: attendingIds.map((studentProfileId) => ({
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
    const profile = await this.resolveDriverProfile(tenantId, driverUserId);
    const today = dateOnly(new Date());
    const trip = await this.prisma.dailyTrip.findFirst({
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
          include: { studentProfile: { include: { user: true } } },
          orderBy: { createdAt: 'asc' },
        },
      },
    });
    return trip;
  }

  async startTrip(tenantId: string, driverUserId: string, tripId: string) {
    const trip = await this.assertTripForDriver(tenantId, driverUserId, tripId);
    if (trip.status !== 'SCHEDULED') {
      throw new AppError(409, 'INVALID_STATE', 'Trip is not in SCHEDULED state');
    }
    const updated = await this.prisma.dailyTrip.update({
      where: { id: tripId },
      data: { status: 'IN_PROGRESS', startedAt: new Date() },
    });
    await this.audit(tenantId, driverUserId, 'TRIP_STARTED', 'DailyTrip', tripId);
    return updated;
  }

  async setStudentStatus(
    tenantId: string,
    driverUserId: string,
    tripId: string,
    studentProfileId: string,
    status: 'WAITING' | 'BOARDED' | 'NOT_READY' | 'MISSED',
  ) {
    const trip = await this.assertTripForDriver(tenantId, driverUserId, tripId);
    if (trip.status !== 'IN_PROGRESS') {
      throw new AppError(409, 'INVALID_STATE', 'Trip is not in progress');
    }
    const now = new Date();
    return this.prisma.tripStudent.update({
      where: { dailyTripId_studentProfileId: { dailyTripId: tripId, studentProfileId } },
      data: {
        status,
        boardedAt: status === 'BOARDED' ? now : undefined,
        missedAt: status === 'MISSED' ? now : undefined,
      },
    });
  }

  async completeTrip(tenantId: string, actorUserId: string, tripId: string) {
    const trip = await this.prisma.dailyTrip.findFirst({ where: { id: tripId, tenantId } });
    if (!trip) throw new AppError(404, 'NOT_FOUND', 'Trip not found');
    if (trip.status !== 'IN_PROGRESS') {
      throw new AppError(409, 'INVALID_STATE', 'Trip is not in progress');
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.dailyTrip.update({
        where: { id: tripId },
        data: { status: 'COMPLETED', completedAt: new Date() },
      });
      // Only BOARDED students become transport-attendance-confirmed.
      await tx.tripStudent.updateMany({
        where: { dailyTripId: tripId, status: 'BOARDED' },
        data: { transportConfirmed: true },
      });
    });

    await this.audit(tenantId, actorUserId, 'TRIP_COMPLETED', 'DailyTrip', tripId);
    return this.prisma.dailyTrip.findUnique({ where: { id: tripId } });
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

  private async audit(
    tenantId: string,
    actorUserId: string,
    action: string,
    entityType: string,
    entityId: string,
    metadata?: Prisma.InputJsonValue,
  ) {
    await this.prisma.auditLog.create({
      data: { tenantId, actorUserId, action, entityType, entityId, metadata },
    });
  }
}
