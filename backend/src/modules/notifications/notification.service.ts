import type { Prisma, PrismaClient } from '@prisma/client';
import { AppError } from '../../utils/appError';
import { toPrismaPagination, type Paginated } from '../../utils/pagination';
import {
  MockPushProvider,
  type PushPayload,
  type PushProvider,
} from '../../providers/notifications';

export class NotificationService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly provider: PushProvider,
  ) {}

  async send(userId: string, payload: PushPayload): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) return;

    await this.prisma.notification.create({
      data: {
        tenantId: user.tenantId,
        userId,
        type: payload.type,
        title: payload.title,
        body: payload.body ?? null,
        data: (payload.data ?? null) as Prisma.InputJsonValue,
      },
    });

    const devices = await this.prisma.deviceToken.findMany({ where: { userId, isActive: true } });
    await Promise.all(devices.map((d) => this.provider.send(d.platform, d.token, payload)));
  }

  async sendToAll(userIds: string[], payload: PushPayload): Promise<void> {
    for (const userId of new Set(userIds)) await this.send(userId, payload);
  }

  async listMine(userId: string, page: number, limit: number): Promise<Paginated<unknown>> {
    const [items, total] = await Promise.all([
      this.prisma.notification.findMany({
        where: { userId },
        ...toPrismaPagination(page, limit),
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.notification.count({ where: { userId } }),
    ]);
    return { items, page, limit, total };
  }

  async unreadCount(userId: string): Promise<number> {
    return this.prisma.notification.count({ where: { userId, isRead: false } });
  }

  async markAllRead(userId: string): Promise<number> {
    const { count } = await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
    return count;
  }

  async markRead(userId: string, id: string) {
    const notification = await this.prisma.notification.findFirst({ where: { id, userId } });
    if (!notification) throw new AppError(404, 'NOT_FOUND', 'Notification not found');
    return this.prisma.notification.update({
      where: { id },
      data: { isRead: true, readAt: new Date() },
    });
  }
}

/**
 * The notification service with the push provider configured for this
 * server. Push is a placeholder until real FCM / Huawei / APNs credentials are
 * set up; notifications are always kept for the in-app list.
 */
export function createNotificationService(prisma: PrismaClient): NotificationService {
  return new NotificationService(prisma, new MockPushProvider());
}
