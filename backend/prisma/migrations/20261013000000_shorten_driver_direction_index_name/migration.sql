-- PostgreSQL truncates identifiers to 63 bytes. Give the direction-aware
-- driver conflict index a stable explicit name for drift verification.
ALTER INDEX "DailyTrip_tenantId_driverProfileId_tripDate_direction_active_ke"
  RENAME TO "DailyTrip_driver_direction_active_key";
