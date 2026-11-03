import { z } from 'zod';
import { idSchema, isoDateSchema } from '../../validation/common';

export const tripCreateSchema = z
  .object({
    routeId: idSchema,
    busId: idSchema,
    driverProfileId: idSchema,
    tripDate: isoDateSchema,
    direction: z.enum(['OUTBOUND', 'RETURN']).optional(),
  })
  .strict();

export const tripStudentStatusSchema = z
  .object({
    status: z.enum(['WAITING', 'BOARDED', 'NOT_READY', 'MISSED']),
  })
  .strict();

export type TripCreateInput = z.infer<typeof tripCreateSchema>;

/** A driver adds today's trip to their bus, on its fixed route. */
export const driverTripCreateSchema = z
  .object({ direction: z.enum(['OUTBOUND', 'RETURN']) })
  .strict();
