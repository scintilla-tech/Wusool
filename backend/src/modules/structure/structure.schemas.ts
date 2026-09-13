import { z } from 'zod';
import { latitudeSchema, longitudeSchema, nameSchema, idSchema } from '../../validation/common';

export const listQuerySchema = z
  .object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    active: z.enum(['true', 'false']).optional(),
  })
  .strict();

export const branchCreateSchema = z
  .object({
    name: nameSchema,
    code: z.string().trim().min(1).max(64).optional(),
    latitude: latitudeSchema.optional(),
    longitude: longitudeSchema.optional(),
    radius: z.coerce.number().positive().max(5000).optional(),
  })
  .strict();

export const branchUpdateSchema = branchCreateSchema.partial().strict();

export const neighborhoodCreateSchema = z
  .object({
    name: nameSchema,
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
  })
  .strict();

export const busUpdateSchema = busCreateSchema.partial().strict();

export const routeCreateSchema = z
  .object({
    name: nameSchema,
    code: z.string().trim().min(1).max(64).optional(),
    branchId: idSchema.optional(),
  })
  .strict();

export const routeUpdateSchema = routeCreateSchema.partial().strict();

export const routeStopSchema = z
  .object({
    neighborhoodId: idSchema,
    sequenceOrder: z.coerce.number().int().min(0).default(0),
  })
  .strict();

export const routeStopsUpdateSchema = z
  .object({
    stops: z.array(routeStopSchema).max(200),
  })
  .strict();
