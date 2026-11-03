import { Prisma, type PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { toPrismaPagination } from '../../utils/pagination';
import {
  IMPORT_ROLES,
  pickRoleFields,
  type ImportRole,
  type PersonRow,
} from '../imports/imports.fields';
import { ImportsService, takenIssue } from '../imports/imports.service';
import { toAsciiDigits, type RowIssue } from '../imports/imports.validation';
import type { PeopleListQuery, PersonStatus } from './people.schemas';

const routeSummarySelect = {
  id: true,
  name: true,
  code: true,
  isActive: true,
} satisfies Prisma.RouteSelect;

const busSummarySelect = {
  id: true,
  plateNumber: true,
  name: true,
  isActive: true,
} satisfies Prisma.BusSelect;

/** The one active assignment, newest first should there ever be two. */
const current = { where: { isActive: true }, orderBy: { assignedAt: 'desc' }, take: 1 } as const;

const listSelect = {
  id: true,
  role: true,
  firstName: true,
  lastName: true,
  phone: true,
  email: true,
  isActive: true,
  // Read only to report whether the account is activated; never returned.
  passwordHash: true,
  createdAt: true,
  studentProfile: {
    select: {
      id: true,
      studentId: true,
      studentAssignments: {
        ...current,
        where: { isActive: true, routeId: { not: null } },
        select: { route: { select: routeSummarySelect } },
      },
    },
  },
  driverProfile: {
    select: {
      id: true,
      employeeId: true,
      driverAssignments: { ...current, select: { bus: { select: busSummarySelect } } },
    },
  },
  supervisorProfile: {
    select: {
      id: true,
      employeeId: true,
      supervisorBusAssignments: { ...current, select: { bus: { select: busSummarySelect } } },
    },
  },
  fieldSupervisorProfile: { select: { id: true, employeeId: true } },
} satisfies Prisma.UserSelect;

/** Staff details the admin can edit; never part of lists. */
const staffDetails = {
  nationalIdOrIqama: true,
  nationality: true,
  joinDate: true,
  iqamaExpiry: true,
} as const;

const detailSelect = {
  ...listSelect,
  driverProfile: { select: { ...listSelect.driverProfile.select, ...staffDetails } },
  supervisorProfile: { select: { ...listSelect.supervisorProfile.select, ...staffDetails } },
  fieldSupervisorProfile: {
    select: { ...listSelect.fieldSupervisorProfile.select, ...staffDetails },
  },
} satisfies Prisma.UserSelect;

type ListUser = Prisma.UserGetPayload<{ select: typeof listSelect }>;
type DetailUser = Prisma.UserGetPayload<{ select: typeof detailSelect }>;

type RouteSummary = Prisma.RouteGetPayload<{ select: typeof routeSummarySelect }>;
type BusSummary = Prisma.BusGetPayload<{ select: typeof busSummarySelect }>;

export interface PersonSummary {
  /** The account id. */
  id: string;
  /** The role profile's id, which assignments refer to. */
  profileId: string | null;
  role: ImportRole;
  firstName: string;
  lastName: string;
  phone: string;
  email: string | null;
  /** University number for students, employee number for staff. */
  number: string | null;
  isActive: boolean;
  /** False until the person signs in for the first time and sets a password. */
  isActivated: boolean;
  /** Students only: the route they ride. */
  route?: RouteSummary | null;
  /** Drivers and supervisors only: the bus they work on. */
  bus?: BusSummary | null;
}

export interface PersonDetail extends PersonSummary {
  /** The editable values, as the add and edit forms show them. */
  row: PersonRow;
  createdAt: Date;
}

export type StatusCounts = Partial<Record<PersonStatus, number>>;

export type UpdateResult =
  { saved: true; person: PersonDetail } | { saved: false; issues: RowIssue[] };

function profileOf(user: ListUser) {
  return (
    user.studentProfile ??
    user.driverProfile ??
    user.supervisorProfile ??
    user.fieldSupervisorProfile
  );
}

function toSummary(user: ListUser): PersonSummary {
  const role = user.role as ImportRole;
  const profile = profileOf(user);
  const summary: PersonSummary = {
    id: user.id,
    profileId: profile?.id ?? null,
    role,
    firstName: user.firstName,
    lastName: user.lastName,
    phone: user.phone,
    email: user.email,
    number:
      user.studentProfile?.studentId ??
      (profile && 'employeeId' in profile ? profile.employeeId : null),
    isActive: user.isActive,
    isActivated: user.passwordHash !== null,
  };
  if (role === 'STUDENT') {
    summary.route = user.studentProfile?.studentAssignments[0]?.route ?? null;
  } else if (role === 'DRIVER') {
    summary.bus = user.driverProfile?.driverAssignments[0]?.bus ?? null;
  } else if (role === 'SUPERVISOR') {
    summary.bus = user.supervisorProfile?.supervisorBusAssignments[0]?.bus ?? null;
  }
  return summary;
}

/** +966501234567 as the admin types it: 0501234567. */
function localPhone(phone: string): string {
  return phone.startsWith('+966') ? `0${phone.slice(4)}` : phone;
}

const isoDay = (date: Date | null) => date?.toISOString().slice(0, 10);

function toRow(user: DetailUser): PersonRow {
  const row: PersonRow = {
    firstName: user.firstName,
    lastName: user.lastName,
    phone: localPhone(user.phone),
  };
  if (user.email) row.email = user.email;
  if (user.studentProfile) {
    row.studentId = user.studentProfile.studentId;
    return row;
  }
  const staff = user.driverProfile ?? user.supervisorProfile ?? user.fieldSupervisorProfile;
  if (!staff) return row;
  row.employeeId = staff.employeeId;
  const optional = {
    nationalIdOrIqama: staff.nationalIdOrIqama ?? undefined,
    nationality: staff.nationality ?? undefined,
    joinDate: isoDay(staff.joinDate),
    iqamaExpiry: isoDay(staff.iqamaExpiry),
  };
  for (const [key, value] of Object.entries(optional)) {
    if (value) row[key as keyof PersonRow] = value;
  }
  return row;
}

/** People of `role` on route or bus `target`, or on none when `target` is "none". */
function assignmentFilter(role: ImportRole, target: string): Prisma.UserWhereInput {
  const none = target === 'none';
  switch (role) {
    case 'STUDENT': {
      const onRoute = { isActive: true, routeId: none ? { not: null } : target };
      return {
        studentProfile: { studentAssignments: none ? { none: onRoute } : { some: onRoute } },
      };
    }
    case 'DRIVER': {
      const onBus = { isActive: true, ...(none ? {} : { busId: target }) };
      return { driverProfile: { driverAssignments: none ? { none: onBus } : { some: onBus } } };
    }
    case 'SUPERVISOR': {
      const onBus = { isActive: true, ...(none ? {} : { busId: target }) };
      return {
        supervisorProfile: {
          supervisorBusAssignments: none ? { none: onBus } : { some: onBus },
        },
      };
    }
    case 'FIELD_SUPERVISOR':
      throw new AppError(400, 'INVALID_FILTER', 'Field supervisors are not assigned');
  }
}

function numberFilter(role: ImportRole, value: Prisma.StringFilter): Prisma.UserWhereInput {
  switch (role) {
    case 'STUDENT':
      return { studentProfile: { studentId: value } };
    case 'DRIVER':
      return { driverProfile: { employeeId: value } };
    case 'SUPERVISOR':
      return { supervisorProfile: { employeeId: value } };
    case 'FIELD_SUPERVISOR':
      return { fieldSupervisorProfile: { employeeId: value } };
  }
}

/** Every word must appear in a name, the email, the number, or the phone. */
function searchFilters(role: ImportRole, q: string | undefined): Prisma.UserWhereInput[] {
  const words = toAsciiDigits(q ?? '')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 5);
  return words.map((word) => {
    const contains = { contains: word, mode: 'insensitive' as const };
    const anyOf: Prisma.UserWhereInput[] = [
      { firstName: contains },
      { lastName: contains },
      { email: contains },
      numberFilter(role, contains),
    ];
    // Phones are stored as +9665XXXXXXXX; people type 05XXXXXXXX.
    const digits = /^\+?\d+$/.test(word) ? word.replace(/^\+?(966|0)/, '') : '';
    if (digits) anyOf.push({ phone: { contains: digits } });
    return { OR: anyOf };
  });
}

function statusFilter(role: ImportRole, status: PersonStatus): Prisma.UserWhereInput {
  switch (status) {
    case 'all':
      return {};
    case 'active':
      return { isActive: true, passwordHash: { not: null } };
    case 'pending':
      return { isActive: true, passwordHash: null };
    case 'disabled':
      return { isActive: false };
    case 'unassigned':
      return { isActive: true, ...assignmentFilter(role, 'none') };
  }
}

/**
 * The admin's directory of students and staff: searching and paging through
 * them, editing their details, and disabling or re-enabling their accounts.
 */
export class PeopleService {
  private readonly imports: ImportsService;

  constructor(private readonly prisma: PrismaClient) {
    this.imports = new ImportsService(prisma);
  }

  async list(tenantId: string, query: PeopleListQuery) {
    const { role, page, limit } = query;
    const target = role === 'STUDENT' ? query.routeId : query.busId;
    const base: Prisma.UserWhereInput[] = [
      { tenantId, role },
      ...searchFilters(role, query.q),
      ...(target ? [assignmentFilter(role, target)] : []),
    ];
    const where: Prisma.UserWhereInput = { AND: [...base, statusFilter(role, query.status)] };
    const counted: PersonStatus[] =
      role === 'FIELD_SUPERVISOR'
        ? ['all', 'active', 'pending', 'disabled']
        : ['all', 'active', 'pending', 'disabled', 'unassigned'];

    const [users, total, ...countValues] = await Promise.all([
      this.prisma.user.findMany({
        where,
        ...toPrismaPagination(page, limit),
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
        select: listSelect,
      }),
      this.prisma.user.count({ where }),
      ...counted.map((status) =>
        this.prisma.user.count({ where: { AND: [...base, statusFilter(role, status)] } }),
      ),
    ]);
    const counts: StatusCounts = Object.fromEntries(
      counted.map((status, index) => [status, countValues[index]]),
    );
    return { items: users.map(toSummary), page, limit, total, counts };
  }

  async get(tenantId: string, id: string): Promise<PersonDetail> {
    const user = await this.find(tenantId, id);
    return { ...toSummary(user), row: toRow(user), createdAt: user.createdAt };
  }

  /**
   * Replaces the person's details with `input`. Optional values left empty are
   * cleared. Problems are returned per field, as when adding people.
   */
  async update(
    tenantId: string,
    actorUserId: string,
    id: string,
    input: PersonRow,
  ): Promise<UpdateResult> {
    const user = await this.find(tenantId, id);
    const role = user.role as ImportRole;
    const { clean, issues } = await this.imports.checkEdit(
      tenantId,
      role,
      id,
      pickRoleFields(role, input),
    );
    if (!clean) return { saved: false, issues };

    const staff = {
      employeeId: clean.id,
      nationalIdOrIqama: clean.nationalIdOrIqama ?? null,
      nationality: clean.nationality ?? null,
      joinDate: clean.joinDate ?? null,
      iqamaExpiry: clean.iqamaExpiry ?? null,
    };
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.user.update({
          where: { id },
          data: {
            firstName: clean.firstName,
            lastName: clean.lastName,
            phone: clean.phone,
            email: clean.email ?? null,
          },
        });
        const where = { userId: id };
        if (role === 'STUDENT') {
          await tx.studentProfile.update({ where, data: { studentId: clean.id } });
        } else if (role === 'DRIVER') {
          await tx.driverProfile.update({ where, data: staff });
        } else if (role === 'SUPERVISOR') {
          await tx.supervisorProfile.update({ where, data: staff });
        } else {
          await tx.fieldSupervisorProfile.update({ where, data: staff });
        }
        await tx.auditLog.create({
          data: {
            tenantId,
            actorUserId,
            action: 'PERSON_UPDATED',
            entityType: 'User',
            entityId: id,
            metadata: { role },
          },
        });
      });
    } catch (error) {
      // Another admin may have used the same value since the check.
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return { saved: false, issues: [takenIssue(error, role)] };
      }
      throw error;
    }
    return { saved: true, person: await this.get(tenantId, id) };
  }

  /**
   * Stops the person signing in, signs them out everywhere, and takes them off
   * their route or bus.
   */
  async disable(tenantId: string, actorUserId: string, id: string): Promise<PersonDetail> {
    const user = await this.find(tenantId, id);
    if (user.isActive) {
      await this.prisma.$transaction(async (tx) => {
        await tx.user.update({ where: { id }, data: { isActive: false } });
        await tx.refreshSession.updateMany({
          where: { userId: id, revokedAt: null },
          data: { revokedAt: new Date() },
        });
        await tx.deviceToken.updateMany({
          where: { userId: id, isActive: true },
          data: { isActive: false },
        });
        const ended = await this.endAssignments(tx, tenantId, user);
        await tx.auditLog.create({
          data: {
            tenantId,
            actorUserId,
            action: 'PERSON_DISABLED',
            entityType: 'User',
            entityId: id,
            metadata: { role: user.role, endedAssignments: ended },
          },
        });
      });
    }
    return this.get(tenantId, id);
  }

  async enable(tenantId: string, actorUserId: string, id: string): Promise<PersonDetail> {
    const user = await this.find(tenantId, id);
    if (!user.isActive) {
      await this.prisma.$transaction(async (tx) => {
        await tx.user.update({ where: { id }, data: { isActive: true } });
        await tx.auditLog.create({
          data: {
            tenantId,
            actorUserId,
            action: 'PERSON_ENABLED',
            entityType: 'User',
            entityId: id,
            metadata: { role: user.role },
          },
        });
      });
    }
    return this.get(tenantId, id);
  }

  private async endAssignments(
    tx: Prisma.TransactionClient,
    tenantId: string,
    user: DetailUser,
  ): Promise<number> {
    const off = { data: { isActive: false } };
    if (user.studentProfile) {
      const { count } = await tx.studentAssignment.updateMany({
        where: { tenantId, studentProfileId: user.studentProfile.id, isActive: true },
        ...off,
      });
      return count;
    }
    if (user.driverProfile) {
      const { count } = await tx.driverAssignment.updateMany({
        where: { tenantId, driverProfileId: user.driverProfile.id, isActive: true },
        ...off,
      });
      return count;
    }
    if (user.supervisorProfile) {
      const { count } = await tx.supervisorBusAssignment.updateMany({
        where: { tenantId, supervisorProfileId: user.supervisorProfile.id, isActive: true },
        ...off,
      });
      return count;
    }
    return 0;
  }

  private async find(tenantId: string, id: string): Promise<DetailUser> {
    const user = await this.prisma.user.findFirst({
      where: { id, tenantId, role: { in: [...IMPORT_ROLES] } },
      select: detailSelect,
    });
    if (!user) throw new AppError(404, 'NOT_FOUND', 'Person not found');
    return user;
  }
}
