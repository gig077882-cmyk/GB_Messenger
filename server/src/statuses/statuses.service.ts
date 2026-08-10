import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { Prisma } from '../generated/prisma/client';
import { PUBLIC_USER_SELECT } from '../users/users.select';
import type {
  CreateStatusDto,
  StatusPrivacyDto,
  StatusReplyDto,
} from './dto/statuses.dto';

const STATUS_TTL_MS = 24 * 60 * 60 * 1000;
const messageInclude = {
  sender: {
    select: { id: true, displayName: true, avatarUrl: true, username: true },
  },
};

@Injectable()
export class StatusesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
  ) {}

  async create(userId: string, dto: CreateStatusDto) {
    const expiresAt = new Date(Date.now() + STATUS_TTL_MS);
    const status = await this.prisma.userStatus.create({
      data: {
        userId,
        kind: dto.kind ?? 'IMAGE',
        text: dto.text,
        textColor: dto.textColor,
        bgColor: dto.bgColor,
        fontStyle: dto.fontStyle,
        mediaKey: dto.mediaKey,
        mediaUrl: dto.mediaUrl ?? null,
        mediaMeta: dto.mediaMeta as Prisma.InputJsonValue | undefined,
        caption: dto.caption ?? null,
        expiresAt,
      },
    });

    const full = await this.prisma.userStatus.findUnique({
      where: { id: status.id },
      include: { user: { select: PUBLIC_USER_SELECT } },
    });

    const contacts = await this.prisma.contact.findMany({
      where: { userId },
      select: { contactUserId: true },
    });
    this.realtime.emitToUsers(
      contacts.map((c) => c.contactUserId),
      'status:new',
      full,
    );

    return full;
  }

  async feed(userId: string) {
    const contacts = await this.prisma.contact.findMany({
      where: { userId },
      select: { contactUserId: true },
    });
    const blockedByMe = await this.prisma.blockedUser.findMany({
      where: { userId },
      select: { blockedUserId: true },
    });
    const blockedMe = await this.prisma.blockedUser.findMany({
      where: { blockedUserId: userId },
      select: { userId: true },
    });
    const blockedIds = new Set([
      ...blockedByMe.map((b) => b.blockedUserId),
      ...blockedMe.map((b) => b.userId),
    ]);

    const viewerIds = [userId, ...contacts.map((c) => c.contactUserId)].filter(
      (id) => !blockedIds.has(id),
    );

    const statuses = await this.prisma.userStatus.findMany({
      where: {
        userId: { in: viewerIds },
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, displayName: true, avatarUrl: true } },
        _count: { select: { views: true } },
      },
    });

    const myViewed = await this.prisma.storyView.findMany({
      where: { viewerId: userId },
      select: { storyId: true },
    });
    const viewedSet = new Set(myViewed.map((v) => v.storyId));

    return statuses.map((s) => ({
      id: s.id,
      userId: s.userId,
      user: s.user,
      kind: s.kind,
      text: s.text,
      textColor: s.textColor,
      bgColor: s.bgColor,
      fontStyle: s.fontStyle,
      mediaKey: s.mediaKey,
      mediaUrl: s.mediaUrl,
      mediaMeta: s.mediaMeta,
      caption: s.caption,
      createdAt: s.createdAt,
      expiresAt: s.expiresAt,
      viewed: viewedSet.has(s.id),
      viewsCount: s.userId === userId ? s._count.views : undefined,
      own: s.userId === userId,
    }));
  }

  async view(userId: string, statusId: string) {
    const status = await this.prisma.userStatus.findUnique({
      where: { id: statusId },
    });
    if (!status) throw new NotFoundException('Status not found');
    if (status.userId === userId) return { viewed: true };

    await this.prisma.storyView.upsert({
      where: { storyId_viewerId: { storyId: statusId, viewerId: userId } },
      create: { storyId: statusId, viewerId: userId },
      update: {},
    });

    return { viewed: true };
  }

  async remove(userId: string, statusId: string) {
    const status = await this.prisma.userStatus.findUnique({
      where: { id: statusId },
    });
    if (!status) throw new NotFoundException('Status not found');
    if (status.userId !== userId) {
      throw new ForbiddenException('Not your status');
    }
    await this.prisma.userStatus.delete({ where: { id: statusId } });
    return { deleted: true };
  }

  async reply(userId: string, statusId: string, dto: StatusReplyDto) {
    const status = await this.prisma.userStatus.findUnique({
      where: { id: statusId },
    });
    if (!status) throw new NotFoundException('Status not found');

    // Create a reply message in a direct chat with the status owner
    const chat = await this.prisma.chat.findFirst({
      where: {
        type: 'DIRECT',
        AND: [
          { members: { some: { userId } } },
          { members: { some: { userId: status.userId } } },
        ],
      },
    });

    let chatId = dto.chatId;
    if (!chatId) {
      if (chat) {
        chatId = chat.id;
      } else {
        const created = await this.prisma.chat.create({
          data: {
            type: 'DIRECT',
            members: {
              create: [{ userId }, { userId: status.userId }],
            },
          },
        });
        chatId = created.id;
      }
    }

    const msg = await this.prisma.message.create({
      data: {
        chatId: chatId,
        senderId: userId,
        type: 'TEXT',
        text: dto.text,
      },
      include: messageInclude,
    });

    this.realtime.emitToChat(chatId, 'message:new', msg);
    return msg;
  }

  async updatePrivacy(userId: string, statusId: string, dto: StatusPrivacyDto) {
    const status = await this.prisma.userStatus.findUnique({
      where: { id: statusId },
    });
    if (!status) throw new NotFoundException('Status not found');
    if (status.userId !== userId)
      throw new ForbiddenException('Not your status');

    return this.prisma.userStatus.update({
      where: { id: statusId },
      data: { privacy: dto.privacy ?? 'everyone' },
      select: { id: true, privacy: true },
    });
  }
}
