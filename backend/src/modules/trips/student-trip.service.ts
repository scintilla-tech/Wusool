import type { PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { dateOnly } from '../../utils/date';
import type { LatestLocation, LocationService } from '../tracking/location.service';

export interface StudentTripView {
  trip: { id: string; status: string; routeName: string | null; busPlate: string | null } | null;
  myStatus: string | null;
  latestLocation: LatestLocation | null;
}

export class StudentTripService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly locationService: LocationService,
  ) {}

  async getTodayTrip(tenantId: string, studentUserId: string): Promise<StudentTripView> {
    const profile = await this.prisma.studentProfile.findFirst({
      where: { userId: studentUserId, tenantId, isActive: true },
      select: { id: true },
    });
    if (!profile) throw new AppError(404, 'NOT_FOUND', 'Student profile not found');

    const assignment = await this.prisma.studentAssignment.findFirst({
      where: { tenantId, studentProfileId: profile.id, isActive: true },
      select: { routeId: true },
    });
    if (!assignment?.routeId) {
      return { trip: null, myStatus: null, latestLocation: null };
    }

    const trip = await this.prisma.dailyTrip.findFirst({
      where: {
        tenantId,
        routeId: assignment.routeId,
        tripDate: dateOnly(new Date()),
        status: { in: ['IN_PROGRESS', 'SCHEDULED'] },
        tripStudents: { some: { tenantId, studentProfileId: profile.id } },
      },
      select: {
        id: true,
        status: true,
        route: { select: { name: true } },
        bus: { select: { plateNumber: true } },
      },
      orderBy: { direction: 'asc' },
    });
    if (!trip) {
      return { trip: null, myStatus: null, latestLocation: null };
    }

    const tripStudent = await this.prisma.tripStudent.findUnique({
      where: {
        dailyTripId_studentProfileId: { dailyTripId: trip.id, studentProfileId: profile.id },
      },
      select: { status: true },
    });

    return {
      trip: {
        id: trip.id,
        status: trip.status,
        routeName: trip.route?.name ?? null,
        busPlate: trip.bus?.plateNumber ?? null,
      },
      myStatus: tripStudent?.status ?? null,
      latestLocation: this.locationService.getLatest(trip.id),
    };
  }
}
