import { Injectable, Logger, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { PrismaService } from '../prisma/prisma.service';

type SendResult = {
  successCount: number;
};

/**
 * FCM push notifications. Lazily initializes firebase-admin only when
 * FCM_SERVICE_ACCOUNT is configured; otherwise all sends are no-ops
 * (useful for local development).
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private enabled = false;

  constructor(
    @Optional() private readonly config?: ConfigService,
    private readonly prisma?: PrismaService,
  ) {
    this.initFirebase();
  }

  private initFirebase(): void {
    const raw = this.config?.get<string>('FCM_SERVICE_ACCOUNT');
    if (!raw) {
      this.logger.log('FCM not configured - push notifications disabled');
      return;
    }
    try {
      const serviceAccount = JSON.parse(raw) as Parameters<typeof cert>[0];
      if (getApps().length === 0) {
        initializeApp({ credential: cert(serviceAccount) });
      }
      this.enabled = true;
      this.logger.log('FCM initialized');
    } catch (err) {
      this.logger.error(`FCM init failed: ${(err as Error).message}`);
    }
  }

  async notifyNewMessage(input: {
    chatId: string;
    chatName: string | null;
    senderId: string;
    senderName: string;
    messageId: string;
    preview: string;
    recipientIds: string[];
  }): Promise<void> {
    if (!this.enabled || !this.prisma || input.recipientIds.length === 0) return;

    try {
      const rows = await this.prisma.pushToken.findMany({
        where: { userId: { in: input.recipientIds } },
        select: { token: true },
      });
      if (rows.length === 0) return;

      const result: SendResult = await getMessaging().sendEachForMulticast({
        tokens: rows.map((r) => r.token),
        notification: {
          title: input.senderName,
          body: input.preview,
        },
        data: {
          chatId: input.chatId,
          chatName: input.chatName ?? '',
          messageId: input.messageId,
          senderId: input.senderId,
        },
      });
      this.logger.debug(`Push sent: ${result.successCount}/${rows.length}`);
    } catch (err) {
      this.logger.warn(`Push send failed: ${(err as Error).message}`);
    }
  }
}
