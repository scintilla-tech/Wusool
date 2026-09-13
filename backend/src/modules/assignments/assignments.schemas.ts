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
