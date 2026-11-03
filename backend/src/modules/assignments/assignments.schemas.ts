import { z } from 'zod';
import { idSchema } from '../../validation/common';

export const assignStudentSchema = z
  .object({
    studentProfileId: idSchema,
    routeId: idSchema.optional(),
    branchId: idSchema.optional(),
  })
  .strict();

export const assignDriverSchema = z
  .object({
    driverProfileId: idSchema,
    busId: idSchema,
  })
  .strict();

export const assignSupervisorSchema = z
  .object({
    supervisorProfileId: idSchema,
    busId: idSchema,
  })
  .strict();

/** Puts students on a route, moving any already on another one. */
export const assignStudentsToRouteSchema = z
  .object({
    routeId: idSchema,
    studentProfileIds: z.array(idSchema).min(1).max(500),
  })
  .strict();
