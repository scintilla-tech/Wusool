import type { PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { dateOnly } from '../../utils/date';

const DAY_MS = 86_400_000;

/** The longest holiday one entry can hold. */
export const MAX_HOLIDAY_DAYS = 120;

const isoDay = (date: Date) => date.toISOString().slice(0, 10);

interface HolidayRecord {
  id: string;
  name: string;
  startDate: Date;
  endDate: Date;
}

function toDto(holiday: HolidayRecord) {
  return {
    id: holiday.id,
    name: holiday.name,
    startDate: isoDay(holiday.startDate),
    endDate: isoDay(holiday.endDate),
    days: Math.round((holiday.endDate.getTime() - holiday.startDate.getTime()) / DAY_MS) + 1,
  };
}

const select = { id: true, name: true, startDate: true, endDate: true } as const;

/** The university's holiday calendar: days the morning schedule skips. */
export class HolidayService {
  constructor(private readonly prisma: PrismaClient) {}

  /** Holidays not over yet, soonest first. */
  async list(tenantId: string) {
    const holidays = await this.prisma.holiday.findMany({
      where: { tenantId, endDate: { gte: dateOnly(new Date()) } },
      orderBy: { startDate: 'asc' },
      select,
    });
    return holidays.map(toDto);
  }

  async create(
    tenantId: string,
    actorUserId: string,
    input: { name: string; startDate: Date; endDate: Date },
  ) {
    const range = this.range(input.startDate, input.endDate);
    const holiday = await this.prisma.holiday.create({
      data: { tenantId, name: input.name, ...range },
      select,
    });
    await this.audit(tenantId, actorUserId, 'HOLIDAY_ADDED', holiday.id);
    return toDto(holiday);
  }

  async update(
    tenantId: string,
    actorUserId: string,
    id: string,
    input: { name?: string; startDate?: Date; endDate?: Date },
  ) {
    const existing = await this.find(tenantId, id);
    const range = this.range(
      input.startDate ?? existing.startDate,
      input.endDate ?? existing.endDate,
    );
    const holiday = await this.prisma.holiday.update({
      where: { id },
      data: { ...(input.name !== undefined ? { name: input.name } : {}), ...range },
      select,
    });
    await this.audit(tenantId, actorUserId, 'HOLIDAY_CHANGED', id);
    return toDto(holiday);
  }

  async remove(tenantId: string, actorUserId: string, id: string) {
    await this.find(tenantId, id);
    await this.prisma.holiday.delete({ where: { id } });
    await this.audit(tenantId, actorUserId, 'HOLIDAY_REMOVED', id);
  }

  private range(start: Date, end: Date) {
    const startDate = dateOnly(start);
    const endDate = dateOnly(end);
    const days = Math.round((endDate.getTime() - startDate.getTime()) / DAY_MS) + 1;
    if (days < 1) throw new AppError(422, 'INVALID_RANGE', 'The holiday ends before it starts');
    if (days > MAX_HOLIDAY_DAYS) {
      throw new AppError(422, 'INVALID_RANGE', `A holiday is at most ${MAX_HOLIDAY_DAYS} days`);
    }
    return { startDate, endDate };
  }

  private async find(tenantId: string, id: string) {
    const holiday = await this.prisma.holiday.findFirst({ where: { id, tenantId }, select });
    if (!holiday) throw new AppError(404, 'NOT_FOUND', 'Holiday not found');
    return holiday;
  }

  private audit(tenantId: string, actorUserId: string, action: string, entityId: string) {
    return this.prisma.auditLog.create({
      data: { tenantId, actorUserId, action, entityType: 'Holiday', entityId },
    });
  }
}
