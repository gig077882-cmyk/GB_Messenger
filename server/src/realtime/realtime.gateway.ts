import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { RealtimeService } from './realtime.service';
import { CallsService } from '../calls/calls.service';
import { MessageStatus } from '../generated/prisma/enums';
import { PRESENCE_KEY } from './presence.keys';
import type { AuthUser } from '../common/types/auth-user';

interface WsUser extends AuthUser {
  deviceId?: string;
}

function socketUser(socket: Socket): WsUser | undefined {
  return (socket.data as { user?: WsUser }).user;
}

@WebSocketGateway({
  cors: { origin: '*', credentials: true },
})
export class RealtimeGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(RealtimeGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly realtime: RealtimeService,
    private readonly calls: CallsService,
  ) {}

  afterInit(server: Server): void {
    this.realtime.setServer(server);
    this.logger.log('Realtime gateway initialized');
  }

  async handleConnection(socket: Socket): Promise<void> {
    const user = socketUser(socket);
    const userId = user?.id;
    if (!userId) {
      socket.disconnect(true);
      return;
    }

    await this.redis.sadd(PRESENCE_KEY(userId), socket.id, 3600);
    void socket.join(`user:${userId}`);

    const memberships = await this.prisma.chatMember.findMany({
      where: { userId },
      select: { chatId: true },
    });
    for (const m of memberships) {
      void socket.join(`chat:${m.chatId}`);
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { isOnline: true },
    });

    // Mark messages sent while offline as delivered
    const delivered = await this.prisma.messageStatusRow.updateMany({
      where: {
        userId,
        status: MessageStatus.SENT,
        message: { senderId: { not: userId } },
      },
      data: { status: MessageStatus.DELIVERED },
    });
    if (delivered.count > 0) {
      const updated = await this.prisma.messageStatusRow.findMany({
        where: {
          userId,
          status: MessageStatus.DELIVERED,
          updatedAt: { gt: new Date(Date.now() - 5000) },
          message: { senderId: { not: userId } },
        },
        select: { messageId: true, message: { select: { chatId: true } } },
        take: 500,
      });
      const byChat = new Map<string, string[]>();
      for (const row of updated) {
        const list = byChat.get(row.message.chatId) ?? [];
        list.push(row.messageId);
        byChat.set(row.message.chatId, list);
      }
      for (const [chatId, messageIds] of byChat) {
        this.realtime.emitToChat(chatId, 'messages:delivered', {
          chatId,
          userId,
          messageIds,
          deliveredAt: new Date().toISOString(),
        });
      }
    }

    void this.broadcastPresence(userId, true);
  }

  async handleDisconnect(socket: Socket): Promise<void> {
    const user = socketUser(socket);
    if (!user) return;
    const userId = user.id;

    await this.redis.srem(PRESENCE_KEY(userId), socket.id);
    const count = await this.redis.scard(PRESENCE_KEY(userId));
    if (count === 0) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { isOnline: false, lastSeenAt: new Date() },
      });
      void this.broadcastPresence(userId, false);
    }
  }

  @SubscribeMessage('typing')
  async onTyping(
    @ConnectedSocket() socket: Socket,
    @MessageBody() payload: { chatId: string; isTyping: boolean },
  ): Promise<void> {
    const user = socketUser(socket);
    if (!user || !payload?.chatId) return;

    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: payload.chatId, userId: user.id } },
      include: { user: { select: { displayName: true } } },
    });
    if (!member) return;

    socket.to(`chat:${payload.chatId}`).emit('typing', {
      chatId: payload.chatId,
      userId: user.id,
      displayName: member.user.displayName,
      isTyping: !!payload.isTyping,
    });
  }

  @SubscribeMessage('messages:read')
  async onMessagesRead(
    @ConnectedSocket() socket: Socket,
    @MessageBody() payload: { chatId: string; messageIds: string[] },
  ): Promise<void> {
    const user = socketUser(socket);
    if (!user) return;
    if (
      !payload?.chatId ||
      !Array.isArray(payload.messageIds) ||
      payload.messageIds.length === 0
    )
      return;

    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: payload.chatId, userId: user.id } },
    });
    if (!member) return;

    const result = await this.prisma.messageStatusRow.updateMany({
      where: {
        userId: user.id,
        messageId: { in: payload.messageIds },
        status: { not: MessageStatus.READ },
      },
      data: { status: MessageStatus.READ },
    });

    if (result.count > 0) {
      this.realtime.emitToChat(payload.chatId, 'read:receipts', {
        chatId: payload.chatId,
        userId: user.id,
        messageIds: payload.messageIds,
        readAt: new Date().toISOString(),
      });

      const lastMsg = payload.messageIds[payload.messageIds.length - 1];
      await this.prisma.chatMember.update({
        where: { chatId_userId: { chatId: payload.chatId, userId: user.id } },
        data: { lastReadMessageId: lastMsg },
      });
    }
  }

  @SubscribeMessage('call:invite')
  async onCallInvite(
    @ConnectedSocket() socket: Socket,
    @MessageBody() payload: { chatId: string; type: 'AUDIO' | 'VIDEO' },
  ): Promise<void> {
    const user = socketUser(socket);
    if (!user || !payload?.chatId) return;

    const call = await this.calls.startCall(
      user.id,
      payload.chatId,
      payload.type,
    );
    if (!call) return;

    this.realtime.emitToChat(payload.chatId, 'call:invite', call);
  }

  @SubscribeMessage('call:end')
  async onCallEnd(
    @ConnectedSocket() socket: Socket,
    @MessageBody() payload: { callId: string },
  ): Promise<void> {
    const user = socketUser(socket);
    if (!user || !payload?.callId) return;

    const ended = await this.calls.endCall(user.id, payload.callId);
    if (ended) {
      this.realtime.emitToChat(ended.chatId, 'call:end', {
        callId: ended.id,
        chatId: ended.chatId,
        status: ended.status,
      });
    }
  }

  @SubscribeMessage('presence:get')
  async onPresenceGet(
    @MessageBody() payload: { userIds: string[] },
  ): Promise<Record<string, { isOnline: boolean; lastSeenAt: string | null }>> {
    if (!Array.isArray(payload?.userIds)) return {};
    const users = await this.prisma.user.findMany({
      where: { id: { in: payload.userIds } },
      select: { id: true, isOnline: true, lastSeenAt: true },
    });
    return Object.fromEntries(
      users.map((u) => [
        u.id,
        {
          isOnline: u.isOnline,
          lastSeenAt: u.lastSeenAt?.toISOString() ?? null,
        },
      ]),
    );
  }

  private async broadcastPresence(
    userId: string,
    isOnline: boolean,
  ): Promise<void> {
    const contacts = await this.prisma.contact.findMany({
      where: { userId },
      select: { contactUserId: true },
    });
    this.realtime.emitToUsers(
      contacts.map((c) => c.contactUserId),
      'presence:update',
      { userId, isOnline, lastSeenAt: new Date().toISOString() },
    );
  }
}
