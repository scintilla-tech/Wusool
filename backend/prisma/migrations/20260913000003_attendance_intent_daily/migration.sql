-- DropForeignKey
ALTER TABLE "AttendanceIntent" DROP CONSTRAINT "AttendanceIntent_dailyTripId_fkey";

-- DropIndex
DROP INDEX "AttendanceIntent_tenantId_studentProfileId_idx";

-- DropIndex
DROP INDEX "AttendanceIntent_dailyTripId_studentProfileId_key";

-- AlterTable
ALTER TABLE "AttendanceIntent" DROP COLUMN "dailyTripId",
ADD COLUMN     "tripDate" DATE NOT NULL,
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- CreateIndex
CREATE INDEX "AttendanceIntent_tenantId_tripDate_idx" ON "AttendanceIntent"("tenantId", "tripDate");

-- CreateIndex
CREATE UNIQUE INDEX "AttendanceIntent_studentProfileId_tripDate_key" ON "AttendanceIntent"("studentProfileId", "tripDate");
