/**
 * Guard against Prisma migration drift silently dropping raw PostgreSQL
 * constraints that cannot be expressed in schema.prisma.
 *
 * Prisma cannot express partial unique indexes or CHECK constraints, so these
 * are created in raw SQL migrations. `prisma migrate dev` will therefore report
 * them as "drift" and may generate a migration that drops them. This script
 * asserts they still exist in the target database so CI can catch regressions.
 *
 * Usage: DATABASE_URL=... npm run db:check-constraints
 */
import { PrismaClient } from '@prisma/client';

const REQUIRED_PARTIAL_INDEXES = [
  'StudentAssignment_tenantId_studentProfileId_active_key',
  'DriverAssignment_tenantId_busId_active_key',
  'DriverAssignment_tenantId_driverProfileId_active_key',
  'SupervisorBusAssignment_tenantId_busId_active_key',
  'DailyTrip_tenantId_busId_tripDate_direction_active_key',
  'DailyTrip_driver_direction_active_key',
  'DailyTrip_tenantId_busId_in_progress_key',
  'DailyTrip_tenantId_driverProfileId_in_progress_key',
];

const REQUIRED_UNIQUE_INDEXES = ['DeviceToken_token_key'];

const REQUIRED_CHECK_CONSTRAINTS = [
  'User_role_tenant_check',
  'AttendanceSession_closure_consistency',
  'AttendanceIntent_expectedFinishMinutes_check',
  'AttendanceIntent_finish_time_outbound_only',
  'AttendanceAudit_expectedFinishMinutes_check',
];

async function main(): Promise<void> {
  const prisma = new PrismaClient();
  try {
    const indexes = await prisma.$queryRaw<Array<{ indexname: string }>>`
      SELECT indexname FROM pg_indexes WHERE indexdef LIKE '%WHERE%'
    `;
    const indexNames = new Set(indexes.map((row) => row.indexname));
    for (const name of REQUIRED_PARTIAL_INDEXES) {
      if (!indexNames.has(name)) {
        throw new Error(`Missing partial unique index: ${name}`);
      }
    }

    const allIndexes = await prisma.$queryRaw<Array<{ indexname: string }>>`
      SELECT indexname FROM pg_indexes
    `;
    const allIndexNames = new Set(allIndexes.map((row) => row.indexname));
    for (const name of REQUIRED_UNIQUE_INDEXES) {
      if (!allIndexNames.has(name)) {
        throw new Error(`Missing unique index: ${name}`);
      }
    }

    const constraints = await prisma.$queryRaw<Array<{ conname: string }>>`
      SELECT conname FROM pg_constraint WHERE contype = 'c'
    `;
    const constraintNames = new Set(constraints.map((row) => row.conname));
    for (const name of REQUIRED_CHECK_CONSTRAINTS) {
      if (!constraintNames.has(name)) {
        throw new Error(`Missing CHECK constraint: ${name}`);
      }
    }

    console.log(
      `Verified ${REQUIRED_PARTIAL_INDEXES.length} partial indexes, ${REQUIRED_UNIQUE_INDEXES.length} unique index(es), and ${REQUIRED_CHECK_CONSTRAINTS.length} CHECK constraint(s).`,
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
