import { z } from 'zod';
import { idSchema } from '../../validation/common';
import { IMPORT_ROLES } from '../imports/imports.fields';
import { personRowSchema } from '../imports/imports.schemas';

/**
 * - active: can sign in
 * - pending: added, but has not set a password yet
 * - disabled: turned off by an admin
 * - unassigned: not disabled, and on no route (students) or bus (drivers, supervisors)
 */
export const PERSON_STATUSES = ['all', 'active', 'pending', 'disabled', 'unassigned'] as const;
export type PersonStatus = (typeof PERSON_STATUSES)[number];

/** A route or bus id, or "none" for people without one. */
const assignmentTarget = z.union([idSchema, z.literal('none')]);

export const peopleListQuerySchema = z
  .object({
    role: z.enum(IMPORT_ROLES),
    /** Words matched against names, phone, email and university or employee number. */
    q: z.string().trim().max(100).optional(),
    status: z.enum(PERSON_STATUSES).default('all'),
    routeId: assignmentTarget.optional(),
    busId: assignmentTarget.optional(),
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(30),
  })
  .strict()
  .superRefine((query, ctx) => {
    const onBuses = query.role === 'DRIVER' || query.role === 'SUPERVISOR';
    if (query.routeId !== undefined && query.role !== 'STUDENT') {
      ctx.addIssue({ code: 'custom', path: ['routeId'], message: 'Only students ride routes' });
    }
    if (query.busId !== undefined && !onBuses) {
      ctx.addIssue({
        code: 'custom',
        path: ['busId'],
        message: 'Only drivers and supervisors work on buses',
      });
    }
    if (query.status === 'unassigned' && query.role === 'FIELD_SUPERVISOR') {
      ctx.addIssue({
        code: 'custom',
        path: ['status'],
        message: 'Field supervisors are not assigned',
      });
    }
  });

export const personUpdateSchema = z.object({ row: personRowSchema }).strict();

export type PeopleListQuery = z.infer<typeof peopleListQuerySchema>;
