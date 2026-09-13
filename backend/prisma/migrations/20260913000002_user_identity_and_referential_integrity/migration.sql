-- DropForeignKey
ALTER TABLE "StudentProfile" DROP CONSTRAINT "StudentProfile_userId_fkey";

-- DropForeignKey
ALTER TABLE "DriverProfile" DROP CONSTRAINT "DriverProfile_userId_fkey";

-- DropForeignKey
ALTER TABLE "SupervisorProfile" DROP CONSTRAINT "SupervisorProfile_userId_fkey";

-- DropForeignKey
ALTER TABLE "FieldSupervisorProfile" DROP CONSTRAINT "FieldSupervisorProfile_userId_fkey";

-- DropForeignKey
ALTER TABLE "StudentAssignment" DROP CONSTRAINT "StudentAssignment_studentProfileId_fkey";

-- DropForeignKey
ALTER TABLE "DriverAssignment" DROP CONSTRAINT "DriverAssignment_driverProfileId_fkey";

-- DropForeignKey
ALTER TABLE "DriverAssignment" DROP CONSTRAINT "DriverAssignment_busId_fkey";

-- DropForeignKey
ALTER TABLE "SupervisorBusAssignment" DROP CONSTRAINT "SupervisorBusAssignment_supervisorProfileId_fkey";

-- DropForeignKey
ALTER TABLE "SupervisorBusAssignment" DROP CONSTRAINT "SupervisorBusAssignment_busId_fkey";

-- DropForeignKey
ALTER TABLE "AttendanceIntent" DROP CONSTRAINT "AttendanceIntent_studentProfileId_fkey";

-- DropForeignKey
ALTER TABLE "AttendanceIntent" DROP CONSTRAINT "AttendanceIntent_dailyTripId_fkey";

-- DropForeignKey
ALTER TABLE "TripStudent" DROP CONSTRAINT "TripStudent_dailyTripId_fkey";

-- DropForeignKey
ALTER TABLE "TripStudent" DROP CONSTRAINT "TripStudent_studentProfileId_fkey";

-- DropIndex
DROP INDEX "User_email_key";

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "firstName" TEXT NOT NULL,
ADD COLUMN     "lastName" TEXT NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "User_tenantId_email_key" ON "User"("tenantId", "email");

-- AddForeignKey
ALTER TABLE "StudentProfile" ADD CONSTRAINT "StudentProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DriverProfile" ADD CONSTRAINT "DriverProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupervisorProfile" ADD CONSTRAINT "SupervisorProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FieldSupervisorProfile" ADD CONSTRAINT "FieldSupervisorProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StudentAssignment" ADD CONSTRAINT "StudentAssignment_studentProfileId_fkey" FOREIGN KEY ("studentProfileId") REFERENCES "StudentProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DriverAssignment" ADD CONSTRAINT "DriverAssignment_driverProfileId_fkey" FOREIGN KEY ("driverProfileId") REFERENCES "DriverProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DriverAssignment" ADD CONSTRAINT "DriverAssignment_busId_fkey" FOREIGN KEY ("busId") REFERENCES "Bus"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupervisorBusAssignment" ADD CONSTRAINT "SupervisorBusAssignment_supervisorProfileId_fkey" FOREIGN KEY ("supervisorProfileId") REFERENCES "SupervisorProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupervisorBusAssignment" ADD CONSTRAINT "SupervisorBusAssignment_busId_fkey" FOREIGN KEY ("busId") REFERENCES "Bus"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AttendanceIntent" ADD CONSTRAINT "AttendanceIntent_studentProfileId_fkey" FOREIGN KEY ("studentProfileId") REFERENCES "StudentProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AttendanceIntent" ADD CONSTRAINT "AttendanceIntent_dailyTripId_fkey" FOREIGN KEY ("dailyTripId") REFERENCES "DailyTrip"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TripStudent" ADD CONSTRAINT "TripStudent_dailyTripId_fkey" FOREIGN KEY ("dailyTripId") REFERENCES "DailyTrip"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TripStudent" ADD CONSTRAINT "TripStudent_studentProfileId_fkey" FOREIGN KEY ("studentProfileId") REFERENCES "StudentProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Raw SQL (not expressible in Prisma): role/tenantId invariant.
-- All university roles require a tenantId; only PLATFORM_SUPER_ADMIN may be null.
ALTER TABLE "User" ADD CONSTRAINT "User_role_tenant_check"
  CHECK ("role" = 'PLATFORM_SUPER_ADMIN' OR "tenantId" IS NOT NULL);
