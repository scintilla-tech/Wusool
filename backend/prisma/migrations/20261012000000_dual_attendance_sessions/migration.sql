-- Dual attendance sessions with direction, auditable actors, and driver closure.
-- Existing daily attendance is preserved as OUTBOUND. No rows are deleted.
BEGIN;

CREATE TYPE "TripDirection" AS ENUM ('OUTBOUND', 'RETURN');
CREATE TYPE "AttendanceSessionStatus" AS ENUM ('OPEN', 'CLOSED');
CREATE TYPE "AttendanceActorSource" AS ENUM (
  'STUDENT_SELF_REGISTRATION',
  'DRIVER_ASSISTED_REGISTRATION'
);

ALTER TABLE "DailyTrip"
  ADD COLUMN "direction" "TripDirection" NOT NULL DEFAULT 'OUTBOUND';

CREATE TABLE "AttendanceSession" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "routeId" TEXT NOT NULL,
  "dailyTripId" TEXT,
  "operationalDate" DATE NOT NULL,
  "direction" "TripDirection" NOT NULL,
  "status" "AttendanceSessionStatus" NOT NULL DEFAULT 'OPEN',
  "closedByDriverProfileId" TEXT,
  "closedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AttendanceSession_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "AttendanceSession_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "AttendanceSession_routeId_fkey" FOREIGN KEY ("routeId") REFERENCES "Route"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "AttendanceSession_dailyTripId_fkey" FOREIGN KEY ("dailyTripId") REFERENCES "DailyTrip"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "AttendanceSession_closedByDriverProfileId_fkey" FOREIGN KEY ("closedByDriverProfileId") REFERENCES "DriverProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "AttendanceSession_closure_consistency" CHECK (
    ("status" = 'OPEN' AND "closedByDriverProfileId" IS NULL AND "closedAt" IS NULL)
    OR
    ("status" = 'CLOSED' AND "closedByDriverProfileId" IS NOT NULL AND "closedAt" IS NOT NULL)
  )
);

CREATE UNIQUE INDEX "AttendanceSession_dailyTripId_key" ON "AttendanceSession"("dailyTripId");
CREATE UNIQUE INDEX "AttendanceSession_tenantId_routeId_operationalDate_direction_key"
  ON "AttendanceSession"("tenantId", "routeId", "operationalDate", "direction");
CREATE INDEX "AttendanceSession_tenantId_operationalDate_direction_status_idx"
  ON "AttendanceSession"("tenantId", "operationalDate", "direction", "status");

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM "AttendanceIntent" ai
    WHERE NOT EXISTS (
      SELECT 1 FROM "StudentAssignment" sa
      WHERE sa."tenantId" = ai."tenantId"
        AND sa."studentProfileId" = ai."studentProfileId"
        AND sa."isActive" = true
        AND sa."routeId" IS NOT NULL
    )
  ) THEN
    RAISE EXCEPTION 'Legacy attendance without an active route assignment requires operator review';
  END IF;
END $$;

-- Create sessions from scheduled trips first, then cover legacy attendance dates
-- which may have been registered before a trip was created.
INSERT INTO "AttendanceSession" (
  "id", "tenantId", "routeId", "dailyTripId", "operationalDate", "direction"
)
SELECT
  'session-trip-' || dt."id", dt."tenantId", dt."routeId", dt."id", dt."tripDate", dt."direction"
FROM "DailyTrip" dt
WHERE dt."routeId" IS NOT NULL
ON CONFLICT ("tenantId", "routeId", "operationalDate", "direction") DO NOTHING;

INSERT INTO "AttendanceSession" (
  "id", "tenantId", "routeId", "operationalDate", "direction"
)
SELECT DISTINCT
  'session-legacy-' || md5(ai."tenantId" || ':' || sa."routeId" || ':' || ai."tripDate"::text),
  ai."tenantId", sa."routeId", ai."tripDate", 'OUTBOUND'::"TripDirection"
FROM "AttendanceIntent" ai
JOIN LATERAL (
  SELECT candidate."routeId"
  FROM "StudentAssignment" candidate
  WHERE candidate."tenantId" = ai."tenantId"
    AND candidate."studentProfileId" = ai."studentProfileId"
    AND candidate."isActive" = true
    AND candidate."routeId" IS NOT NULL
  ORDER BY candidate."assignedAt" DESC, candidate."id"
  LIMIT 1
) sa ON true
ON CONFLICT ("tenantId", "routeId", "operationalDate", "direction") DO NOTHING;

-- Attach any trip whose session was originally created from legacy attendance.
UPDATE "AttendanceSession" s
SET "dailyTripId" = dt."id", "updatedAt" = CURRENT_TIMESTAMP
FROM "DailyTrip" dt
WHERE s."dailyTripId" IS NULL
  AND s."tenantId" = dt."tenantId"
  AND s."routeId" = dt."routeId"
  AND s."operationalDate" = dt."tripDate"
  AND s."direction" = dt."direction";

ALTER TABLE "AttendanceIntent"
  ADD COLUMN "attendanceSessionId" TEXT,
  ADD COLUMN "operationalDate" DATE,
  ADD COLUMN "direction" "TripDirection",
  ADD COLUMN "expectedFinishMinutes" INTEGER,
  ADD COLUMN "source" "AttendanceActorSource",
  ADD COLUMN "actorUserId" TEXT,
  ADD COLUMN "actorRole" "Role";

UPDATE "AttendanceIntent" ai
SET
  "attendanceSessionId" = s."id",
  "operationalDate" = ai."tripDate",
  "direction" = 'OUTBOUND',
  "source" = 'STUDENT_SELF_REGISTRATION',
  "actorUserId" = sp."userId",
  "actorRole" = 'STUDENT'
FROM "StudentProfile" sp
JOIN LATERAL (
  SELECT candidate."routeId"
  FROM "StudentAssignment" candidate
  WHERE candidate."tenantId" = sp."tenantId"
    AND candidate."studentProfileId" = sp."id"
    AND candidate."isActive" = true
    AND candidate."routeId" IS NOT NULL
  ORDER BY candidate."assignedAt" DESC, candidate."id"
  LIMIT 1
) sa ON true
JOIN "AttendanceSession" s
  ON s."tenantId" = sp."tenantId"
 AND s."routeId" = sa."routeId"
 AND s."direction" = 'OUTBOUND'
WHERE ai."studentProfileId" = sp."id"
  AND s."operationalDate" = ai."tripDate";

ALTER TABLE "AttendanceIntent"
  ALTER COLUMN "attendanceSessionId" SET NOT NULL,
  ALTER COLUMN "operationalDate" SET NOT NULL,
  ALTER COLUMN "direction" SET NOT NULL,
  ALTER COLUMN "source" SET NOT NULL,
  ALTER COLUMN "actorUserId" SET NOT NULL,
  ALTER COLUMN "actorRole" SET NOT NULL;

DROP INDEX "AttendanceIntent_studentProfileId_tripDate_key";
DROP INDEX "AttendanceIntent_tenantId_tripDate_idx";
ALTER TABLE "AttendanceIntent" DROP COLUMN "tripDate";

ALTER TABLE "AttendanceIntent"
  ADD CONSTRAINT "AttendanceIntent_attendanceSessionId_fkey" FOREIGN KEY ("attendanceSessionId") REFERENCES "AttendanceSession"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "AttendanceIntent_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "AttendanceIntent_expectedFinishMinutes_check" CHECK (
    "expectedFinishMinutes" IS NULL OR ("expectedFinishMinutes" BETWEEN 0 AND 1439)
  ),
  ADD CONSTRAINT "AttendanceIntent_finish_time_outbound_only" CHECK (
    "expectedFinishMinutes" IS NULL OR "direction" = 'OUTBOUND'
  );

CREATE UNIQUE INDEX "AttendanceIntent_attendanceSessionId_studentProfileId_key"
  ON "AttendanceIntent"("attendanceSessionId", "studentProfileId");
CREATE INDEX "AttendanceIntent_tenantId_operationalDate_direction_idx"
  ON "AttendanceIntent"("tenantId", "operationalDate", "direction");
CREATE INDEX "AttendanceIntent_studentProfileId_operationalDate_direction_idx"
  ON "AttendanceIntent"("studentProfileId", "operationalDate", "direction");

CREATE TABLE "AttendanceAudit" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "attendanceSessionId" TEXT NOT NULL,
  "studentProfileId" TEXT NOT NULL,
  "previousStatus" "AttendanceIntentType",
  "attendanceStatus" "AttendanceIntentType" NOT NULL,
  "source" "AttendanceActorSource" NOT NULL,
  "actorUserId" TEXT NOT NULL,
  "actorRole" "Role" NOT NULL,
  "expectedFinishMinutes" INTEGER,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AttendanceAudit_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "AttendanceAudit_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "AttendanceAudit_attendanceSessionId_fkey" FOREIGN KEY ("attendanceSessionId") REFERENCES "AttendanceSession"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "AttendanceAudit_studentProfileId_fkey" FOREIGN KEY ("studentProfileId") REFERENCES "StudentProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "AttendanceAudit_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "AttendanceAudit_expectedFinishMinutes_check" CHECK (
    "expectedFinishMinutes" IS NULL OR ("expectedFinishMinutes" BETWEEN 0 AND 1439)
  )
);

INSERT INTO "AttendanceAudit" (
  "id", "tenantId", "attendanceSessionId", "studentProfileId", "attendanceStatus",
  "source", "actorUserId", "actorRole", "expectedFinishMinutes", "createdAt"
)
SELECT
  'audit-legacy-' || ai."id", ai."tenantId", ai."attendanceSessionId", ai."studentProfileId",
  ai."intent", ai."source", ai."actorUserId", ai."actorRole", ai."expectedFinishMinutes", ai."updatedAt"
FROM "AttendanceIntent" ai;

CREATE INDEX "AttendanceAudit_tenantId_attendanceSessionId_createdAt_idx"
  ON "AttendanceAudit"("tenantId", "attendanceSessionId", "createdAt");
CREATE INDEX "AttendanceAudit_studentProfileId_createdAt_idx"
  ON "AttendanceAudit"("studentProfileId", "createdAt");

-- Two scheduled trips may share a bus/driver on the same operational date only
-- when their directions differ. The global IN_PROGRESS constraints remain.
DROP INDEX "DailyTrip_tenantId_busId_tripDate_active_key";
DROP INDEX "DailyTrip_tenantId_driverProfileId_tripDate_active_key";
CREATE UNIQUE INDEX "DailyTrip_tenantId_busId_tripDate_direction_active_key"
  ON "DailyTrip"("tenantId", "busId", "tripDate", "direction")
  WHERE "status" IN ('SCHEDULED', 'IN_PROGRESS') AND "busId" IS NOT NULL;
CREATE UNIQUE INDEX "DailyTrip_tenantId_driverProfileId_tripDate_direction_active_key"
  ON "DailyTrip"("tenantId", "driverProfileId", "tripDate", "direction")
  WHERE "status" IN ('SCHEDULED', 'IN_PROGRESS') AND "driverProfileId" IS NOT NULL;
CREATE INDEX "DailyTrip_tenantId_driverProfileId_tripDate_direction_idx"
  ON "DailyTrip"("tenantId", "driverProfileId", "tripDate", "direction");
DROP INDEX "DailyTrip_tenantId_driverProfileId_tripDate_idx";

COMMIT;
