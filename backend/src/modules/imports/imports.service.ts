import { Prisma, type PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { EmployeesService } from '../employees/employees.service';
import { StudentsService } from '../students/students.service';
import { idFieldFor, pickRoleFields, type ImportRole, type PersonRow } from './imports.fields';
import { readPeopleFile } from './imports.file';
import { checkRow, findDuplicates, type CleanRow, type RowIssue } from './imports.validation';

export interface DraftSummary {
  id: string;
  role: ImportRole;
  name: string;
  rowCount: number;
  updatedAt: Date;
  createdBy: { firstName: string; lastName: string };
}

export interface DraftDetail extends DraftSummary {
  rows: PersonRow[];
  /** Problems per row, in the same order as `rows`. */
  issues: RowIssue[][];
}

export interface SubmitResult {
  created: number;
  /** Rows not added, kept for the admin to fix. */
  rows: PersonRow[];
  issues: RowIssue[][];
  /** The draft still holding the remaining rows, or null when none is left. */
  draft: DraftSummary | null;
}

const draftSelect = {
  id: true,
  role: true,
  name: true,
  rows: true,
  updatedAt: true,
  createdBy: { select: { firstName: true, lastName: true } },
} satisfies Prisma.ImportDraftSelect;

type DraftRecord = Prisma.ImportDraftGetPayload<{ select: typeof draftSelect }>;

function storedRows(draft: DraftRecord): PersonRow[] {
  return Array.isArray(draft.rows) ? (draft.rows as PersonRow[]) : [];
}

function toSummary(draft: DraftRecord): DraftSummary {
  return {
    id: draft.id,
    role: draft.role as ImportRole,
    name: draft.name,
    rowCount: storedRows(draft).length,
    updatedAt: draft.updatedAt,
    createdBy: draft.createdBy,
  };
}

/** Which value a unique-constraint failure was about, from Prisma's error target. */
export function takenIssue(
  error: Prisma.PrismaClientKnownRequestError,
  role: ImportRole,
): RowIssue {
  const target = JSON.stringify(error.meta?.target ?? '');
  if (target.includes('phone')) return { field: 'phone', code: 'PHONE_TAKEN' };
  if (target.includes('email')) return { field: 'email', code: 'EMAIL_TAKEN' };
  if (target.includes('studentId') || target.includes('employeeId')) {
    return { field: idFieldFor(role), code: 'ID_TAKEN' };
  }
  return { field: null, code: 'ALREADY_EXISTS' };
}

/**
 * Adding students and staff in bulk: reading files, checking rows against each
 * other and existing accounts, creating the accounts, and saved drafts.
 */
export class ImportsService {
  private readonly students: StudentsService;
  private readonly employees: EmployeesService;

  constructor(private readonly prisma: PrismaClient) {
    this.students = new StudentsService(prisma);
    this.employees = new EmployeesService(prisma);
  }

  async readFile(tenantId: string, role: ImportRole, buffer: Buffer, fileName: string) {
    const { rows, missingColumns } = await readPeopleFile(role, buffer, fileName);
    const issues = rows.length > 0 ? await this.check(tenantId, role, rows) : [];
    return { rows, issues, missingColumns };
  }

  /** Problems per row: formats, repeats within the list, and values already in use. */
  async check(tenantId: string, role: ImportRole, rows: PersonRow[]): Promise<RowIssue[][]> {
    return (await this.inspect(tenantId, role, rows)).issues;
  }

  /**
   * Checks new values for an existing person: formats, and values that other
   * accounts already use. `clean` is null when there is any problem.
   */
  async checkEdit(
    tenantId: string,
    role: ImportRole,
    userId: string,
    row: PersonRow,
  ): Promise<{ clean: CleanRow | null; issues: RowIssue[] }> {
    const checked = checkRow(role, row);
    if (!checked.clean) return checked;
    const [taken] = await this.findTaken(tenantId, role, [checked.clean], userId);
    return { clean: taken.length === 0 ? checked.clean : null, issues: taken };
  }

  private async inspect(tenantId: string, role: ImportRole, rows: PersonRow[]) {
    const checked = rows.map((row) => checkRow(role, row));
    const clean = checked.map((result) => result.clean);
    const duplicates = findDuplicates(role, clean);
    const taken = await this.findTaken(tenantId, role, clean);
    const issues = checked.map((result, index) => [
      ...result.issues,
      ...duplicates[index],
      ...taken[index],
    ]);
    return { clean, issues };
  }

  /**
   * Flags phone numbers, emails and ID numbers that existing accounts already
   * use, other than the account of `exceptUserId`.
   */
  private async findTaken(
    tenantId: string,
    role: ImportRole,
    rows: (CleanRow | null)[],
    exceptUserId?: string,
  ): Promise<RowIssue[][]> {
    const valid = rows.filter((row): row is CleanRow => row !== null);
    if (valid.length === 0) return rows.map(() => []);
    const phones = valid.map((row) => row.phone);
    const emails = valid.map((row) => row.email).filter((email): email is string => !!email);
    const ids = valid.map((row) => row.id);
    const others = exceptUserId ? { id: { not: exceptUserId } } : {};

    const [phoneUsers, emailUsers, takenIds] = await Promise.all([
      this.prisma.user.findMany({
        where: { tenantId, phone: { in: phones }, ...others },
        select: { phone: true },
      }),
      emails.length === 0
        ? Promise.resolve([])
        : this.prisma.user.findMany({
            where: { tenantId, email: { in: emails, mode: 'insensitive' }, ...others },
            select: { email: true },
          }),
      this.findTakenIds(tenantId, role, ids, exceptUserId),
    ]);

    const takenPhones = new Set(phoneUsers.map((user) => user.phone));
    const takenEmails = new Set(emailUsers.map((user) => user.email?.toLowerCase()));
    const idField = idFieldFor(role);
    return rows.map((row) => {
      if (!row) return [];
      const issues: RowIssue[] = [];
      if (takenPhones.has(row.phone)) issues.push({ field: 'phone', code: 'PHONE_TAKEN' });
      if (row.email && takenEmails.has(row.email.toLowerCase())) {
        issues.push({ field: 'email', code: 'EMAIL_TAKEN' });
      }
      if (takenIds.has(row.id)) issues.push({ field: idField, code: 'ID_TAKEN' });
      return issues;
    });
  }

  private async findTakenIds(
    tenantId: string,
    role: ImportRole,
    ids: string[],
    exceptUserId?: string,
  ) {
    const others = exceptUserId ? { userId: { not: exceptUserId } } : {};
    const where = { tenantId, employeeId: { in: ids }, ...others };
    const select = { employeeId: true } as const;
    switch (role) {
      case 'STUDENT': {
        const profiles = await this.prisma.studentProfile.findMany({
          where: { tenantId, studentId: { in: ids }, ...others },
          select: { studentId: true },
        });
        return new Set(profiles.map((profile) => profile.studentId));
      }
      case 'DRIVER':
        return new Set(
          (await this.prisma.driverProfile.findMany({ where, select })).map((p) => p.employeeId),
        );
      case 'SUPERVISOR':
        return new Set(
          (await this.prisma.supervisorProfile.findMany({ where, select })).map(
            (p) => p.employeeId,
          ),
        );
      case 'FIELD_SUPERVISOR':
        return new Set(
          (await this.prisma.fieldSupervisorProfile.findMany({ where, select })).map(
            (p) => p.employeeId,
          ),
        );
    }
  }

  /**
   * Creates an account for every row without problems. Rows with problems are
   * returned, and kept in the draft when the rows came from one.
   */
  async submit(
    tenantId: string,
    actorUserId: string,
    role: ImportRole,
    input: PersonRow[],
    draftId?: string,
  ): Promise<SubmitResult> {
    if (draftId) await this.findDraft(tenantId, draftId, role);
    const rows = input.map((row) => pickRoleFields(role, row));
    const { clean, issues } = await this.inspect(tenantId, role, rows);

    let created = 0;
    const remaining: { row: PersonRow; issues: RowIssue[] }[] = [];
    for (const [index, row] of rows.entries()) {
      const values = clean[index];
      if (!values || issues[index].length > 0) {
        remaining.push({ row, issues: issues[index] });
        continue;
      }
      try {
        await this.createAccount(tenantId, role, values);
        created += 1;
      } catch (error) {
        // Another admin may have added the same person since the check.
        if (!(error instanceof Prisma.PrismaClientKnownRequestError) || error.code !== 'P2002') {
          throw error;
        }
        remaining.push({ row, issues: [takenIssue(error, role)] });
      }
    }

    if (created > 0) {
      await this.prisma.auditLog.create({
        data: {
          tenantId,
          actorUserId,
          action: 'PEOPLE_ADDED',
          entityType: 'User',
          metadata: { role, count: created, ...(draftId ? { draftId } : {}) },
        },
      });
    }

    let draft: DraftSummary | null = null;
    if (draftId && remaining.length > 0) {
      draft = await this.saveDraftRows(
        draftId,
        role,
        remaining.map((item) => item.row),
      );
    } else if (draftId) {
      await this.prisma.importDraft.deleteMany({ where: { id: draftId, tenantId } });
    }

    return {
      created,
      rows: remaining.map((item) => item.row),
      issues: remaining.map((item) => item.issues),
      draft,
    };
  }

  private async createAccount(tenantId: string, role: ImportRole, row: CleanRow) {
    const person = {
      firstName: row.firstName,
      lastName: row.lastName,
      phone: row.phone,
      ...(row.email ? { email: row.email } : {}),
    };
    if (role === 'STUDENT') {
      await this.students.create(tenantId, { ...person, studentId: row.id });
      return;
    }
    await this.employees.create(tenantId, {
      ...person,
      role,
      employeeId: row.id,
      nationalIdOrIqama: row.nationalIdOrIqama,
      nationality: row.nationality,
      joinDate: row.joinDate,
      iqamaExpiry: row.iqamaExpiry,
      employmentStatus: 'ACTIVE',
    });
  }

  // ----- Drafts -----

  async listDrafts(tenantId: string, role: ImportRole): Promise<DraftSummary[]> {
    const drafts = await this.prisma.importDraft.findMany({
      where: { tenantId, role },
      orderBy: { updatedAt: 'desc' },
      select: draftSelect,
    });
    return drafts.map(toSummary);
  }

  async getDraft(tenantId: string, id: string): Promise<DraftDetail> {
    const draft = await this.findDraft(tenantId, id);
    const rows = storedRows(draft);
    const role = draft.role as ImportRole;
    return { ...toSummary(draft), rows, issues: await this.check(tenantId, role, rows) };
  }

  async createDraft(
    tenantId: string,
    actorUserId: string,
    input: { role: ImportRole; name: string; rows: PersonRow[] },
  ): Promise<DraftSummary> {
    const draft = await this.prisma.importDraft.create({
      data: {
        tenantId,
        createdById: actorUserId,
        role: input.role,
        name: input.name,
        rows: input.rows.map((row) => pickRoleFields(input.role, row)),
      },
      select: draftSelect,
    });
    return toSummary(draft);
  }

  async updateDraft(
    tenantId: string,
    id: string,
    input: { name?: string; rows: PersonRow[] },
  ): Promise<DraftSummary> {
    const draft = await this.findDraft(tenantId, id);
    return this.saveDraftRows(id, draft.role as ImportRole, input.rows, input.name);
  }

  async deleteDraft(tenantId: string, id: string): Promise<void> {
    await this.findDraft(tenantId, id);
    await this.prisma.importDraft.deleteMany({ where: { id, tenantId } });
  }

  /** Call only after `findDraft` confirmed the draft belongs to the tenant. */
  private async saveDraftRows(
    id: string,
    role: ImportRole,
    rows: PersonRow[],
    name?: string,
  ): Promise<DraftSummary> {
    const draft = await this.prisma.importDraft.update({
      where: { id },
      data: {
        rows: rows.map((row) => pickRoleFields(role, row)),
        ...(name !== undefined ? { name } : {}),
      },
      select: draftSelect,
    });
    return toSummary(draft);
  }

  private async findDraft(tenantId: string, id: string, role?: ImportRole) {
    const draft = await this.prisma.importDraft.findFirst({
      where: { id, tenantId },
      select: draftSelect,
    });
    if (!draft) throw new AppError(404, 'NOT_FOUND', 'Draft not found');
    if (role && draft.role !== role) {
      throw new AppError(409, 'DRAFT_ROLE_MISMATCH', 'The draft holds a different kind of person');
    }
    return draft;
  }
}
