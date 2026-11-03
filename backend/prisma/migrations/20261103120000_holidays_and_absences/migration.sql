-- AlterTable
ALTER TABLE "Tenant" ADD COLUMN     "autoTripMinute" INTEGER NOT NULL DEFAULT 330;

-- CreateTable
CREATE TABLE "Holiday" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "startDate" DATE NOT NULL,
    "endDate" DATE NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Holiday_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DriverAbsence" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "driverProfileId" TEXT NOT NULL,
    "busId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "note" TEXT,
    "coverDriverProfileId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DriverAbsence_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Holiday_tenantId_startDate_idx" ON "Holiday"("tenantId", "startDate");

-- CreateIndex
CREATE INDEX "DriverAbsence_tenantId_busId_date_idx" ON "DriverAbsence"("tenantId", "busId", "date");

-- CreateIndex
CREATE UNIQUE INDEX "DriverAbsence_driverProfileId_date_key" ON "DriverAbsence"("driverProfileId", "date");

-- AddForeignKey
ALTER TABLE "Holiday" ADD CONSTRAINT "Holiday_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DriverAbsence" ADD CONSTRAINT "DriverAbsence_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DriverAbsence" ADD CONSTRAINT "DriverAbsence_driverProfileId_fkey" FOREIGN KEY ("driverProfileId") REFERENCES "DriverProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DriverAbsence" ADD CONSTRAINT "DriverAbsence_busId_fkey" FOREIGN KEY ("busId") REFERENCES "Bus"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DriverAbsence" ADD CONSTRAINT "DriverAbsence_coverDriverProfileId_fkey" FOREIGN KEY ("coverDriverProfileId") REFERENCES "DriverProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

