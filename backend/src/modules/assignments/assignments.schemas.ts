import { z } from 'zod';
import { uuidSchema } from '../../validation/common';

export const assignStudentSchema = z
  .object({
    studentProfileId: uuidSchema,
    routeId: uuidSchema.optional(),
    branchId: uuidSchema.optional(),
  })
  .strict();

export const assignDriverSchema = z
  .object({
    driverProfileId: uuidSchema,
    busId: uuidSchema,
  })
  .strict();

export const assignSupervisorSchema = z
  .object({
    supervisorProfileId: uuidSchema,
    busId: uuidSchema,
  })
  .strict();
