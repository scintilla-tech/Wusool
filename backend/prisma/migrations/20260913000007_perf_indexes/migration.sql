-- CreateIndex
CREATE INDEX "StudentAssignment_tenantId_routeId_idx" ON "StudentAssignment"("tenantId", "routeId");

-- CreateIndex
CREATE INDEX "DailyTrip_tenantId_driverProfileId_tripDate_idx" ON "DailyTrip"("tenantId", "driverProfileId", "tripDate");
