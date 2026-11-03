import { z } from 'zod';
import { latitudeSchema, longitudeSchema, idSchema } from '../../validation/common';

/** Campus, route and neighborhood names often carry a number: "مسار 3", "حي 7". */
const placeNameSchema = z
  .string()
  .trim()
  .min(1, 'Name is required')
  .max(100, 'Name too long')
  .regex(/^[\p{L}\p{M}\p{N}\s.'’()/-]+$/u, 'Name contains invalid characters');

export const listQuerySchema = z
  .object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    active: z.enum(['true', 'false']).optional(),
    /** Matched against names, codes and plate numbers. */
    q: z.string().trim().max(100).optional(),
  })
  .strict();

export const branchCreateSchema = z
  .object({
    name: placeNameSchema,
    code: z.string().trim().min(1).max(64).optional(),
    latitude: latitudeSchema.optional(),
    longitude: longitudeSchema.optional(),
    radius: z.coerce.number().positive().max(5000).optional(),
  })
  .strict();

export const branchUpdateSchema = z
  .object({
    name: placeNameSchema.optional(),
    code: z.string().trim().min(1).max(64).nullable().optional(),
    latitude: latitudeSchema.nullable().optional(),
    longitude: longitudeSchema.nullable().optional(),
    radius: z.coerce.number().positive().max(5000).nullable().optional(),
  })
  .strict();

export const neighborhoodCreateSchema = z
  .object({
    name: placeNameSchema,
    latitude: latitudeSchema.optional(),
    longitude: longitudeSchema.optional(),
  })
  .strict();

export const neighborhoodUpdateSchema = neighborhoodCreateSchema.partial().strict();

export const busCreateSchema = z
  .object({
    plateNumber: z.string().trim().min(1).max(32),
    name: z.string().trim().min(1).max(64).optional(),
    capacity: z.coerce.number().int().min(1).max(200).optional(),
    /** The route the bus runs every school day. */
    routeId: idSchema.optional(),
  })
  .strict();

export const busUpdateSchema = z
  .object({
    plateNumber: z.string().trim().min(1).max(32).optional(),
    name: z.string().trim().min(1).max(64).nullable().optional(),
    capacity: z.coerce.number().int().min(1).max(200).nullable().optional(),
    routeId: idSchema.nullable().optional(),
    /** False takes the bus out of service, as archiving does; true returns it. */
    isActive: z.boolean().optional(),
  })
  .strict();

/**
 * A neighborhood's id. Not only CUIDs: the demo data names its neighborhoods
 * (`demo-AlNarjis`). Each id is still checked to be one of the tenant's.
 */
const neighborhoodIdSchema = z
  .string()
  .trim()
  .min(1)
  .max(64)
  .regex(/^[A-Za-z0-9_-]+$/, 'Invalid ID');

/** Neighborhood ids in the order the route visits them. */
export const routeStopIdsSchema = z.array(neighborhoodIdSchema).max(200);
const stopIdsSchema = routeStopIdsSchema;

export const routeCreateSchema = z
  .object({
    name: placeNameSchema,
    code: z.string().trim().min(1).max(64).optional(),
    branchId: idSchema.optional(),
    stopIds: stopIdsSchema.optional(),
  })
  .strict();

export const routeUpdateSchema = z
  .object({
    name: placeNameSchema.optional(),
    code: z.string().trim().min(1).max(64).nullable().optional(),
    branchId: idSchema.nullable().optional(),
    /** Replaces every stop when given. */
    stopIds: stopIdsSchema.optional(),
    /** False takes the route out of service, as archiving does; true returns it. */
    isActive: z.boolean().optional(),
  })
  .strict();

export const routeStopSchema = z
  .object({
    neighborhoodId: neighborhoodIdSchema,
    sequenceOrder: z.coerce.number().int().min(0).default(0),
  })
  .strict();

export const routeStopsUpdateSchema = z
  .object({
    stops: z.array(routeStopSchema).max(200),
  })
  .strict();
