-- CreateEnum
CREATE TYPE "TripOrigin" AS ENUM ('AUTOMATIC', 'DRIVER', 'ADMIN');

-- AlterTable
ALTER TABLE "Tenant" ADD COLUMN     "autoTrips" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "Bus" ADD COLUMN     "routeId" TEXT;

-- AlterTable
ALTER TABLE "DailyTrip" ADD COLUMN     "coveredDriverProfileId" TEXT,
ADD COLUMN     "origin" "TripOrigin" NOT NULL DEFAULT 'ADMIN';

-- CreateTable
CREATE TABLE "AutoTripRun" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "tripDate" DATE NOT NULL,
    "trips" INTEGER NOT NULL DEFAULT 0,
    "reminders" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AutoTripRun_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AutoTripRun_tenantId_tripDate_key" ON "AutoTripRun"("tenantId", "tripDate");

-- CreateIndex
CREATE UNIQUE INDEX "Bus_routeId_key" ON "Bus"("routeId");

-- AddForeignKey
ALTER TABLE "Bus" ADD CONSTRAINT "Bus_routeId_fkey" FOREIGN KEY ("routeId") REFERENCES "Route"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DailyTrip" ADD CONSTRAINT "DailyTrip_coveredDriverProfileId_fkey" FOREIGN KEY ("coveredDriverProfileId") REFERENCES "DriverProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AutoTripRun" ADD CONSTRAINT "AutoTripRun_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

