import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ChatType, MemberRole } from '../generated/prisma/enums';
import type { ChatMember, Prisma } from '../generated/prisma/client';
import { UsersService } from '../users/users.service';
import { PUBLIC_USER_SELECT, type PublicUser } from '../users/users.select';
import { RealtimeService } from '../realtime/realtime.service';
import { UpdateGroupSettingsDto } from './dto/chats.dto';
import type {
  AddMemberDto,
  CreateDirectChatDto,
  CreateGroupDto,
  ToggleAdminDto,
  UpdateChatDto,
  UpdateMyMembershipDto,
} from './dto/chats.dto';

@Injectable()
export class ChatsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly usersService: UsersService,
    private readonly realtime: RealtimeService,
  ) {}

  async createDirect(userId: string, dto: CreateDirectChatDto) {
    if (userId === dto.userId)
      throw new BadRequestException('Cannot chat with yourself');

    const other = await this.prisma.user.findUnique({
      where: { id: dto.userId },
    });
    if (!other) throw new NotFoundException('User not found');

    if (await this.usersService.isBlocked(userId, dto.userId)) {
      throw new ForbiddenException('You blocked this user');
    }

    const existing = await this.prisma.chat.findFirst({
      where: {
        type: ChatType.DIRECT,
        members: { every: { userId: { in: [userId, dto.userId] } } },
        AND: [
          { members: { some: { userId } } },
          { members: { some: { userId: dto.userId } } },
        ],
      },
    });
    if (existing) return this.getChat(userId, existing.id);

    const chat = await this.prisma.chat.create({
      data: {
        type: ChatType.DIRECT,
        creatorId: userId,
        members: {
          create: [
            { userId, role: MemberRole.MEMBER },
            { userId: dto.userId, role: MemberRole.MEMBER },
          ],
        },
      },
    });

    const detail = await this.getChat(userId, chat.id);
    const otherUser = await this.prisma.user.findUnique({
      where: { id: dto.userId },
      select: PUBLIC_USER_SELECT,
    });
    if (otherUser) {
      this.realtime.emitToUser(dto.userId, 'chat:new', detail);
    }
    return detail;
  }

  async createGroup(userId: string, dto: CreateGroupDto) {
    const memberIds = [...new Set([userId, ...dto.memberIds])];
    const users = await this.prisma.user.findMany({
      where: { id: { in: memberIds } },
      select: { id: true },
    });
    if (users.length !== memberIds.length) {
      throw new BadRequestException('Some users do not exist');
    }

    const chat = await this.prisma.chat.create({
      data: {
        type: ChatType.GROUP,
        name: dto.name,
        avatarKey: dto.avatarKey,
        avatarUrl: dto.avatarUrl,
        creatorId: userId,
        members: {
          create: memberIds.map((id) => ({
            userId: id,
            role: id === userId ? MemberRole.ADMIN : MemberRole.MEMBER,
          })),
        },
      },
    });

    const detail = await this.getChat(userId, chat.id);
    for (const id of memberIds) {
      this.realtime.emitToUser(id, 'chat:new', detail);
    }

    return detail;
  }

  async listChats(userId: string) {
    const memberships = await this.prisma.chatMember.findMany({
      where: { userId },
      include: {
        chat: {
          include: {
            members: {
              include: { user: { select: PUBLIC_USER_SELECT } },
            },
            messages: {
              orderBy: { createdAt: 'desc' },
              take: 1,
              include: { sender: { select: PUBLIC_USER_SELECT } },
            },
          },
        },
      },
      orderBy: { joinedAt: 'desc' },
    });

    const result = await Promise.all(
      memberships.map(
        async (
          m,
        ): Promise<{
          id: string;
          type: ChatType;
          name: string | null;
          avatarUrl: string | null;
          wallpaperUrl: string | null;
          isMuted: boolean;
          iAmAdmin: boolean;
          unreadCount: number;
          lastMessage: unknown;
          members: unknown[];
          otherUser: PublicUser | null;
          lastMessageAt: Date;
        }> => {
          const chat = m.chat;
          let otherUser: PublicUser | null = null;
          let unreadCount = 0;

          if (chat.type === ChatType.DIRECT) {
            const other = chat.members.find((mm) => mm.userId !== userId);
            otherUser = other?.user ?? null;
          }

          if (m.lastReadMessageId) {
            const lastRead = await this.prisma.message.findUnique({
              where: { id: m.lastReadMessageId },
              select: { createdAt: true },
            });
            unreadCount = lastRead
              ? await this.prisma.message.count({
                  where: {
                    chatId: chat.id,
                    senderId: { not: userId },
                    isDeleted: false,
                    createdAt: { gt: lastRead.createdAt },
                  },
                })
              : 0;
          } else {
            unreadCount = await this.prisma.message.count({
              where: {
                chatId: chat.id,
                senderId: { not: userId },
                isDeleted: false,
              },
            });
          }

          return {
            id: chat.id,
            type: chat.type,
            name:
              chat.type === ChatType.GROUP
                ? chat.name
                : (otherUser?.displayName ?? null),
            avatarUrl:
              chat.type === ChatType.GROUP
                ? chat.avatarUrl
                : (otherUser?.avatarUrl ?? null),
            wallpaperUrl: chat.wallpaperUrl,
            isMuted: m.isMuted,
            iAmAdmin: m.role === MemberRole.ADMIN,
            unreadCount,
            lastMessage: chat.messages[0] ?? null,
            members: chat.members.map((cm) => ({
              userId: cm.userId,
              user: cm.user,
              role: cm.role,
              isMuted: cm.isMuted,
              joinedAt: cm.joinedAt,
            })),
            otherUser,
            lastMessageAt:
              chat.lastMessageAt ?? chat.messages[0]?.createdAt ?? m.joinedAt,
          };
        },
      ),
    );

    result.sort(
      (a, b) => b.lastMessageAt.getTime() - a.lastMessageAt.getTime(),
    );
    return result;
  }

  async getChat(userId: string, chatId: string) {
    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId, userId } },
    });
    if (!member) throw new ForbiddenException('Not a chat member');

    const chat = await this.prisma.chat.findUnique({
      where: { id: chatId },
      include: {
        members: { include: { user: { select: PUBLIC_USER_SELECT } } },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          include: { sender: { select: PUBLIC_USER_SELECT } },
        },
      },
    });
    if (!chat) throw new NotFoundException('Chat not found');

    let otherUser: PublicUser | null = null;
    if (chat.type === ChatType.DIRECT) {
      const other = chat.members.find((m) => m.userId !== userId);
      if (other) otherUser = other.user;
    }

    let unreadCount = 0;
    if (member.lastReadMessageId) {
      const lastRead = await this.prisma.message.findUnique({
        where: { id: member.lastReadMessageId },
        select: { createdAt: true },
      });
      unreadCount = lastRead
        ? await this.prisma.message.count({
            where: {
              chatId,
              senderId: { not: userId },
              isDeleted: false,
              createdAt: { gt: lastRead.createdAt },
            },
          })
        : 0;
    } else {
      unreadCount = await this.prisma.message.count({
        where: { chatId, senderId: { not: userId }, isDeleted: false },
      });
    }

    return {
      id: chat.id,
      type: chat.type,
      name: chat.name,
      avatarUrl: chat.avatarUrl,
      wallpaperUrl: chat.wallpaperUrl,
      creatorId: chat.creatorId,
      createdAt: chat.createdAt,
      myRole: member.role,
      iAmAdmin: member.role === MemberRole.ADMIN,
      isMuted: member.isMuted,
      lastReadMessageId: member.lastReadMessageId,
      otherUser,
      lastMessage: chat.messages[0] ?? null,
      lastMessageAt:
        chat.lastMessageAt ?? chat.messages[0]?.createdAt ?? member.joinedAt,
      unreadCount,
      members: chat.members.map((m) => ({
        userId: m.userId,
        user: m.user,
        role: m.role,
        isMuted: m.isMuted,
        joinedAt: m.joinedAt,
      })),
    };
  }

  async updateChat(userId: string, chatId: string, dto: UpdateChatDto) {
    const member = await this.requireMember(chatId, userId);

    const data: Record<string, unknown> = {};
    if (dto.wallpaperUrl !== undefined) data.wallpaperUrl = dto.wallpaperUrl;

    if (
      dto.name !== undefined ||
      dto.avatarKey !== undefined ||
      dto.avatarUrl !== undefined
    ) {
      const chat = await this.prisma.chat.findUnique({ where: { id: chatId } });
      if (!chat) throw new NotFoundException('Chat not found');
      if (chat.type === ChatType.GROUP && member.role !== MemberRole.ADMIN) {
        throw new ForbiddenException('Only admins can change group info');
      }
      if (dto.name !== undefined) data.name = dto.name;
      if (dto.avatarKey !== undefined) data.avatarKey = dto.avatarKey;
      if (dto.avatarUrl !== undefined) data.avatarUrl = dto.avatarUrl;
    }

    const updated = await this.prisma.chat.update({
      where: { id: chatId },
      data,
    });
    const detail = await this.getChat(userId, chatId);
    this.realtime.emitToChat(chatId, 'chat:updated', detail);
    return updated;
  }

  async addMember(userId: string, chatId: string, dto: AddMemberDto) {
    const member = await this.requireMember(chatId, userId);
    const chat = await this.prisma.chat.findUnique({ where: { id: chatId } });
    if (!chat) throw new NotFoundException('Chat not found');

    if (chat.type === ChatType.DIRECT) {
      // Direct chat with a 3rd participant becomes a group
      const target = await this.prisma.user.findUnique({
        where: { id: dto.userIds[0] },
      });
      if (!target) throw new NotFoundException('User not found');
      await this.prisma.$transaction(async (tx: Prisma.TransactionClient) => {
        await tx.chat.update({
          where: { id: chatId },
          data: { type: ChatType.GROUP, creatorId: userId },
        });
        await tx.chatMember.updateMany({
          where: { chatId },
          data: { role: MemberRole.MEMBER },
        });
        await tx.chatMember.update({
          where: { chatId_userId: { chatId, userId } },
          data: { role: MemberRole.ADMIN },
        });
        await tx.chatMember.create({
          data: { chatId, userId: dto.userIds[0], role: MemberRole.MEMBER },
        });
      });
      const detail = await this.getChat(userId, chatId);
      this.realtime.emitToChat(chatId, 'chat:updated', detail);
      this.realtime.emitToUser(dto.userIds[0], 'chat:new', detail);
      return detail;
    }

    if (member.role !== MemberRole.ADMIN) {
      throw new ForbiddenException('Only admins can add members');
    }

    await this.prisma.chatMember.createMany({
      data: dto.userIds.map((id) => ({ chatId, userId: id })),
      skipDuplicates: true,
    });

    const detail = await this.getChat(userId, chatId);
    for (const id of dto.userIds) {
      this.realtime.emitToUser(id, 'chat:new', detail);
    }
    this.realtime.emitToChat(chatId, 'chat:member:added', {
      chatId,
      userIds: dto.userIds,
    });
    return detail;
  }

  async removeMember(
    userId: string,
    chatId: string,
    targetUserId: string,
    self = false,
  ) {
    const member = await this.requireMember(chatId, userId);
    const chat = await this.prisma.chat.findUnique({ where: { id: chatId } });
    if (!chat) throw new NotFoundException('Chat not found');

    if (
      !self &&
      chat.type === ChatType.GROUP &&
      member.role !== MemberRole.ADMIN
    ) {
      throw new ForbiddenException('Only admins can remove members');
    }
    if (!self && userId === targetUserId) {
      throw new BadRequestException('Use leave endpoint');
    }

    await this.prisma.chatMember.deleteMany({
      where: { chatId, userId: targetUserId },
    });

    if (chat.type === ChatType.DIRECT) {
      // Cleanup: delete chat if no members left
      const remaining = await this.prisma.chatMember.count({
        where: { chatId },
      });
      if (remaining === 0) {
        await this.prisma.chat.delete({ where: { id: chatId } });
      }
    } else {
      this.realtime.emitToChat(chatId, 'chat:member:removed', {
        chatId,
        userId: targetUserId,
      });
    }

    return { removed: true };
  }

  async leaveChat(userId: string, chatId: string) {
    await this.requireMember(chatId, userId);
    await this.prisma.chatMember.deleteMany({ where: { chatId, userId } });

    const remaining = await this.prisma.chatMember.count({ where: { chatId } });
    if (remaining === 0) {
      await this.prisma.chat.delete({ where: { id: chatId } });
    } else {
      this.realtime.emitToChat(chatId, 'chat:member:removed', {
        chatId,
        userId,
      });
    }
    return { left: true };
  }

  async generateInviteLink(userId: string, chatId: string) {
    await this.requireAdmin(chatId, userId);
    const code = randomId(8);
    const chat = await this.prisma.chat.update({
      where: { id: chatId },
      data: { inviteLink: code },
      select: { id: true, inviteLink: true },
    });
    return { inviteLink: `gb://${code}`, code: chat.inviteLink };
  }

  async joinByInviteLink(userId: string, code: string) {
    const chat = await this.prisma.chat.findUnique({
      where: { inviteLink: code },
    });
    if (!chat) throw new NotFoundException('Invalid invite link');

    const existing = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: chat.id, userId } },
    });
    if (existing)
      return this.prisma.chat.findUnique({
        where: { id: chat.id },
        include: chatInclude,
      });

    await this.prisma.chatMember.create({
      data: { chatId: chat.id, userId, role: MemberRole.MEMBER },
    });

    const updated = await this.prisma.chat.findUnique({
      where: { id: chat.id },
      include: chatInclude,
    });
    this.realtime.emitToChat(chat.id, 'chat:member:added', {
      chatId: chat.id,
      userId,
    });
    return updated;
  }

  async updateGroupSettings(
    userId: string,
    chatId: string,
    dto: UpdateGroupSettingsDto,
  ) {
    await this.requireAdmin(chatId, userId);
    return this.prisma.chat.update({
      where: { id: chatId },
      data: {
        name: dto.name,
        description: dto.description,
        onlyAdminsCanSend: dto.onlyAdminsCanSend,
        onlyAdminsCanEdit: dto.onlyAdminsCanEdit,
      },
      include: chatInclude,
    });
  }

  async toggleAdmin(userId: string, chatId: string, dto: ToggleAdminDto) {
    const member = await this.requireMember(chatId, userId);
    const chat = await this.prisma.chat.findUnique({ where: { id: chatId } });
    if (!chat || chat.type !== ChatType.GROUP) {
      throw new BadRequestException('Only groups have admins');
    }
    if (member.role !== MemberRole.ADMIN) {
      throw new ForbiddenException('Only admins can promote members');
    }

    await this.prisma.chatMember.update({
      where: { chatId_userId: { chatId, userId: dto.userId } },
      data: { role: dto.isAdmin ? MemberRole.ADMIN : MemberRole.MEMBER },
    });

    this.realtime.emitToChat(chatId, 'chat:member:role', {
      chatId,
      userId: dto.userId,
      role: dto.isAdmin ? 'ADMIN' : 'MEMBER',
    });
    return { updated: true };
  }

  async updateMyMembership(
    userId: string,
    chatId: string,
    dto: UpdateMyMembershipDto,
  ) {
    await this.requireMember(chatId, userId);
    return this.prisma.chatMember.update({
      where: { chatId_userId: { chatId, userId } },
      data: {
        ...(dto.isMuted !== undefined ? { isMuted: dto.isMuted } : {}),
        ...(dto.lastReadMessageId
          ? { lastReadMessageId: dto.lastReadMessageId }
          : {}),
      },
    });
  }

  async isMember(chatId: string, userId: string): Promise<boolean> {
    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId, userId } },
    });
    return !!member;
  }

  private async requireMember(
    chatId: string,
    userId: string,
  ): Promise<ChatMember> {
    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId, userId } },
    });
    if (!member) throw new ForbiddenException('Not a chat member');
    return member;
  }

  private async requireAdmin(chatId: string, userId: string): Promise<void> {
    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId, userId } },
    });
    if (!member || member.role !== 'ADMIN') {
      throw new ForbiddenException('Admin access required');
    }
  }
}

const chatInclude = {
  members: {
    include: { user: { select: PUBLIC_USER_SELECT } },
  },
};

function randomId(length: number): string {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}
