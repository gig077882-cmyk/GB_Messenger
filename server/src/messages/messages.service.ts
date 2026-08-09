import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { RealtimeService } from '../realtime/realtime.service';
import { MediaProcessor } from '../media/media.processor';
import { PushService } from '../push/push.service';
import { ChatsService } from '../chats/chats.service';
import { EncryptionService } from '../common/encryption.service';
import { MessageStatus, MessageType } from '../generated/prisma/enums';
import { PRESENCE_KEY } from '../realtime/presence.keys';
import type { Prisma } from '../generated/prisma/client';
import type {
  EditMessageDto,
  ListMessagesQueryDto,
  SendMessageDto,
} from './dto/messages.dto';

const messageInclude = {
  sender: {
    select: { id: true, displayName: true, avatarUrl: true, username: true },
  },
  statuses: { select: { userId: true, status: true, updatedAt: true } },
  replyTo: {
    select: {
      id: true,
      type: true,
      text: true,
      senderId: true,
      isDeleted: true,
    },
  },
  reactions: {
    select: { userId: true, emoji: true },
    orderBy: { createdAt: 'asc' },
  },
  forwardedFrom: {
    select: { id: true, displayName: true },
  },
} satisfies Prisma.MessageInclude;

export type MessagePayload = Prisma.MessageGetPayload<{
  include: typeof messageInclude;
}>;

@Injectable()
export class MessagesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly realtime: RealtimeService,
    private readonly mediaProcessor: MediaProcessor,
    private readonly push: PushService,
    private readonly chats: ChatsService,
    private readonly encryption: EncryptionService,
  ) {}

  async sendMessage(userId: string, chatId: string, dto: SendMessageDto) {
    if (!dto.text && !dto.mediaKey && !dto.mediaUrl) {
      throw new BadRequestException('Message must have text or media');
    }

    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId, userId } },
    });
    if (!member) throw new ForbiddenException('Not a chat member');

    const chat = await this.prisma.chat.findUnique({
      where: { id: chatId },
      include: { members: { select: { userId: true } } },
    });
    if (!chat) throw new NotFoundException('Chat not found');

    if (chat.type === 'DIRECT') {
      const other = chat.members.find((m) => m.userId !== userId);
      if (other) {
        const blocked = await this.prisma.blockedUser.findFirst({
          where: {
            OR: [
              { userId, blockedUserId: other.userId },
              { userId: other.userId, blockedUserId: userId },
            ],
          },
        });
        if (blocked) throw new ForbiddenException('BLOCKED');
      }
    } else if (chat.type === 'GROUP') {
      // In group chats, check if sender is blocked by any member or has blocked any member
      const otherIds = chat.members
        .map((m) => m.userId)
        .filter((id) => id !== userId);
      if (otherIds.length > 0) {
        const blocked = await this.prisma.blockedUser.findFirst({
          where: {
            OR: [
              { userId, blockedUserId: { in: otherIds } },
              { userId: { in: otherIds }, blockedUserId: userId },
            ],
          },
        });
        if (blocked) throw new ForbiddenException('BLOCKED');
      }
    }

    const type = (dto.type ??
      (dto.mediaKey || dto.mediaUrl ? 'DOCUMENT' : 'TEXT')) as MessageType;

    if (dto.replyToId) {
      const replyTarget = await this.prisma.message.findUnique({
        where: { id: dto.replyToId },
        select: { chatId: true },
      });
      if (!replyTarget || replyTarget.chatId !== chatId) {
        throw new BadRequestException('replyToId is not in this chat');
      }
    }

    const mediaUrl =
      dto.mediaUrl ?? (dto.mediaKey ? this.publicUrl(dto.mediaKey) : undefined);

    const encryptedText = dto.text ? this.encryption.encrypt(dto.text) : null;

    const message = await this.prisma.message.create({
      data: {
        chatId,
        senderId: userId,
        type,
        text: encryptedText,
        mediaKey: dto.mediaKey ?? null,
        mediaUrl: mediaUrl ?? null,
        mediaMeta: dto.mediaMeta as Prisma.InputJsonValue | undefined,
        replyToId: dto.replyToId ?? null,
        statuses: {
          create: chat.members.map((m) => ({
            chatId,
            userId: m.userId,
            status: MessageStatus.SENT,
          })),
        },
      },
      include: messageInclude,
    });

    // Mark as DELIVERED for members who are currently online
    const onlineIds: string[] = [];
    for (const m of chat.members) {
      if (m.userId === userId) continue;
      const conns = await this.redis.scard(PRESENCE_KEY(m.userId));
      if (conns > 0) onlineIds.push(m.userId);
    }
    if (onlineIds.length > 0) {
      await this.prisma.messageStatusRow.updateMany({
        where: {
          messageId: message.id,
          userId: { in: onlineIds },
          status: MessageStatus.SENT,
        },
        data: { status: MessageStatus.DELIVERED },
      });
      message.statuses = message.statuses.map((s) =>
        onlineIds.includes(s.userId)
          ? { ...s, status: MessageStatus.DELIVERED }
          : s,
      );
      this.realtime.emitToChat(chatId, 'messages:delivered', {
        chatId,
        messageIds: [message.id],
        userIds: onlineIds,
        deliveredAt: new Date().toISOString(),
      });
    }

    await this.prisma.chat.update({
      where: { id: chatId },
      data: { lastMessageAt: new Date() },
    });

    this.realtime.emitToChat(chatId, 'message:new', message);

    // Push only to members who are NOT connected via WS (they already got the message)
    const offlineIds = chat.members
      .map((m) => m.userId)
      .filter((id) => id !== userId && !onlineIds.includes(id));
    await this.push.notifyNewMessage({
      chatId,
      chatName: chat.name,
      senderId: userId,
      senderName: message.sender.displayName,
      messageId: message.id,
      preview: this.previewOf(message),
      recipientIds: offlineIds,
    });

    if (
      dto.mediaKey &&
      (type === 'IMAGE' ||
        type === 'VIDEO' ||
        type === 'AUDIO' ||
        type === 'VOICE')
    ) {
      await this.mediaProcessor.enqueue({
        messageId: message.id,
        chatId,
        mediaKey: dto.mediaKey,
        mediaUrl: mediaUrl ?? '',
        type,
      });
    }

    return message;
  }

  async listMessages(
    userId: string,
    chatId: string,
    query: ListMessagesQueryDto,
  ) {
    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId, userId } },
    });
    if (!member) throw new ForbiddenException('Not a chat member');

    const limit = Math.min(query.limit ?? 50, 100);
    const cursor = query.cursor ? this.safeCursor(query.cursor) : null;

    const messages = await this.prisma.message.findMany({
      where: {
        chatId,
        ...(cursor ? { createdAt: { lt: cursor } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: messageInclude,
    });

    return {
      messages: this.decryptMessages(messages.reverse()),
      nextCursor:
        messages.length === limit ? messages[0].createdAt.toISOString() : null,
    };
  }

  async editMessage(userId: string, messageId: string, dto: EditMessageDto) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
    });
    if (!message) throw new NotFoundException('Message not found');
    if (message.senderId !== userId)
      throw new ForbiddenException('Not your message');

    const updated = await this.prisma.message.update({
      where: { id: messageId },
      data: { text: dto.text },
      include: messageInclude,
    });

    this.realtime.emitToChat(message.chatId, 'message:update', {
      chatId: message.chatId,
      messageId,
      text: dto.text,
      updatedAt: updated.updatedAt,
    });
    return updated;
  }

  async deleteMessage(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
    });
    if (!message) throw new NotFoundException('Message not found');

    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: message.chatId, userId } },
    });
    if (!member) throw new ForbiddenException('Not a chat member');

    const isGroup = message.chatId && (await this.isGroup(message.chatId));
    if (message.senderId !== userId && !(isGroup && member.role === 'ADMIN')) {
      throw new ForbiddenException('Cannot delete this message');
    }

    await this.prisma.message.update({
      where: { id: messageId },
      data: { isDeleted: true, text: null },
    });

    this.realtime.emitToChat(message.chatId, 'message:update', {
      chatId: message.chatId,
      messageId,
      isDeleted: true,
    });
    return { deleted: true };
  }

  async addReaction(userId: string, messageId: string, dto: { emoji: string }) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
      select: { chatId: true },
    });
    if (!message) throw new NotFoundException('Message not found');

    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: message.chatId, userId } },
    });
    if (!member) throw new ForbiddenException('Not a chat member');

    const reaction = await this.prisma.messageReaction.upsert({
      where: { messageId_userId: { messageId, userId } },
      create: { messageId, userId, emoji: dto.emoji },
      update: { emoji: dto.emoji },
    });

    this.realtime.emitToChat(message.chatId, 'message:reaction', {
      messageId,
      userId,
      emoji: dto.emoji,
      action: 'added',
    });

    return reaction;
  }

  async removeReaction(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
      select: { chatId: true },
    });
    if (!message) throw new NotFoundException('Message not found');

    await this.prisma.messageReaction.deleteMany({
      where: { messageId, userId },
    });

    this.realtime.emitToChat(message.chatId, 'message:reaction', {
      messageId,
      userId,
      emoji: null,
      action: 'removed',
    });

    return { ok: true };
  }

  async messageInfo(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
      include: {
        statuses: {
          where: { status: { in: ['DELIVERED', 'READ'] } },
          select: { userId: true, status: true, updatedAt: true },
          orderBy: { updatedAt: 'asc' },
        },
      },
    });
    if (!message) throw new NotFoundException('Message not found');
    if (message.senderId !== userId) {
      throw new ForbiddenException('Only sender can view info');
    }

    return {
      messageId: message.id,
      sentAt: message.createdAt,
      deliveredTo: message.statuses.filter((s) => s.status === 'DELIVERED'),
      readTo: message.statuses.filter((s) => s.status === 'READ'),
    };
  }

  async forwardMessage(userId: string, dto: { messageIds: string[]; targetChatId: string }) {
    const targetMember = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: dto.targetChatId, userId } },
    });
    if (!targetMember) throw new ForbiddenException('Not a target chat member');

    const originals = await this.prisma.message.findMany({
      where: { id: { in: dto.messageIds } },
    });

    const created: MessagePayload[] = [];
    for (const orig of originals) {
      const msg = await this.prisma.message.create({
        data: {
          chatId: dto.targetChatId,
          senderId: userId,
          type: orig.type,
          text: orig.text,
          mediaKey: orig.mediaKey,
          mediaUrl: orig.mediaUrl,
          mediaMeta: orig.mediaMeta as Prisma.InputJsonValue | undefined,
          forwardedFromId: orig.senderId,
          statuses: {
            create: { chatId: dto.targetChatId, userId, status: 'SENT' },
          },
        },
        include: messageInclude,
      });
      created.push(msg);
      this.realtime.emitToChat(dto.targetChatId, 'message:new', msg);
    }

    return created;
  }

  async searchMessages(userId: string, chatId: string, q: string) {
    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId, userId } },
    });
    if (!member) throw new ForbiddenException('Not a chat member');

    return this.prisma.message.findMany({
      where: {
        chatId,
        text: { contains: q, mode: 'insensitive' },
        isDeleted: false,
      },
      include: messageInclude,
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  private async isGroup(chatId: string): Promise<boolean> {
    const chat = await this.prisma.chat.findUnique({
      where: { id: chatId },
      select: { type: true },
    });
    return chat?.type === 'GROUP';
  }

  private decryptMessageText(text: string | null): string | null {
    if (!text) return null;
    try {
      return this.encryption.decrypt(text);
    } catch {
      return text;
    }
  }

  decryptMessage(message: MessagePayload): MessagePayload {
    return {
      ...message,
      text: this.decryptMessageText(message.text),
    };
  }

  decryptMessages(messages: MessagePayload[]): MessagePayload[] {
    return messages.map((m) => this.decryptMessage(m));
  }

  private previewOf(message: MessagePayload): string {
    if (message.isDeleted) return 'Message deleted';
    const text = this.decryptMessageText(message.text);
    if (text) return text.slice(0, 120);
    const labels: Record<string, string> = {
      IMAGE: 'Photo',
      VIDEO: 'Video',
      AUDIO: 'Audio',
      VOICE: 'Voice message',
      DOCUMENT: 'Document',
      CALL: 'Call',
    };
    return labels[message.type] ?? 'Message';
  }

  private safeCursor(value: string): Date {
    const date = new Date(value);
    if (Number.isNaN(date.getTime()))
      throw new BadRequestException('Invalid cursor');
    return date;
  }

  private publicUrl(key: string): string {
    const base = process.env.MINIO_PUBLIC_BASE_URL ?? '';
    return `${base}/${key}`;
  }
}
