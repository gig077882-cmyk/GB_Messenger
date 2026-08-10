import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '../generated/prisma/client';
import {
  BlockUserDto,
  RegisterPushTokenDto,
  SearchUsersDto,
  SyncContactsDto,
  UpdatePrivacyDto,
  UpdateProfileDto,
} from './dto/users.dto';
import { PUBLIC_USER_SELECT } from './users.select';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { ...PUBLIC_USER_SELECT, privacySettings: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const data: Record<string, unknown> = {};
    if (dto.displayName !== undefined) data.displayName = dto.displayName;
    if (dto.username !== undefined) data.username = dto.username || null;
    if (dto.bio !== undefined) data.bio = dto.bio;
    if (dto.phone !== undefined) data.phone = dto.phone;
    if (dto.avatarKey !== undefined) data.avatarKey = dto.avatarKey;
    if (dto.avatarUrl !== undefined) data.avatarUrl = dto.avatarUrl;
    if (dto.wallpaperUrl !== undefined) data.wallpaperUrl = dto.wallpaperUrl;
    if (dto.privacySettings !== undefined)
      data.privacySettings = dto.privacySettings;

    return this.prisma.user.update({
      where: { id: userId },
      data,
      select: { ...PUBLIC_USER_SELECT, privacySettings: true },
    });
  }

  async search(userId: string, query: SearchUsersDto) {
    const or: Prisma.UserWhereInput[] = [];
    if (query.q) {
      or.push(
        { displayName: { contains: query.q, mode: 'insensitive' } },
        { username: { contains: query.q, mode: 'insensitive' } },
        { email: { contains: query.q.toLowerCase() } },
      );
    }
    if (query.phone) {
      or.push({ phone: query.phone });
    }
    if (or.length === 0) return [];

    const users = await this.prisma.user.findMany({
      where: { id: { not: userId }, OR: or },
      select: PUBLIC_USER_SELECT,
      take: 50,
    });

    const blockedIds = await this.getBlockedUserIds(userId);
    return users.filter((u) => !blockedIds.has(u.id));
  }

  async syncContacts(userId: string, dto: SyncContactsDto) {
    const normalized = [...new Set(dto.phones.filter(Boolean))];
    const matched = await this.prisma.user.findMany({
      where: { phone: { in: normalized }, id: { not: userId } },
      select: PUBLIC_USER_SELECT,
    });

    // Filter out blocked users
    if (matched.length > 0) {
      const matchedIds = matched.map((m) => m.id);
      const blocked = await this.prisma.blockedUser.findMany({
        where: {
          OR: [
            { userId, blockedUserId: { in: matchedIds } },
            { userId: { in: matchedIds }, blockedUserId: userId },
          ],
        },
        select: { userId: true, blockedUserId: true },
      });
      const blockedIds = new Set(
        blocked.flatMap((b) => [b.userId, b.blockedUserId]),
      );
      const filtered = matched.filter((m) => !blockedIds.has(m.id));

      await this.prisma.contact.createMany({
        data: filtered.map((m) => ({
          userId,
          contactUserId: m.id,
        })),
        skipDuplicates: true,
      });

      return {
        matched: filtered.map((m) => ({
          id: m.id,
          email: m.email,
          displayName: m.displayName,
          username: m.username,
          phone: m.phone,
          avatarKey: m.avatarKey,
          avatarUrl: m.avatarUrl,
          bio: m.bio,
          isOnline: m.isOnline,
          lastSeenAt: m.lastSeenAt,
        })),
      };
    }

    return { matched: [] };
  }

  async listContacts(userId: string) {
    const contacts = await this.prisma.contact.findMany({
      where: { userId },
      select: {
        customName: true,
        contactUser: { select: PUBLIC_USER_SELECT },
      },
    });
    return contacts.map((c) => ({
      customName: c.customName,
      user: c.contactUser,
    }));
  }

  async blockUser(userId: string, dto: BlockUserDto) {
    if (userId === dto.userId)
      throw new BadRequestException('Cannot block yourself');
    const target = await this.prisma.user.findUnique({
      where: { id: dto.userId },
    });
    if (!target) throw new NotFoundException('User not found');

    await this.prisma.blockedUser.upsert({
      where: { userId_blockedUserId: { userId, blockedUserId: dto.userId } },
      create: { userId, blockedUserId: dto.userId },
      update: {},
    });

    return { blocked: true };
  }

  async unblockUser(userId: string, blockedUserId: string) {
    await this.prisma.blockedUser.deleteMany({
      where: { userId, blockedUserId },
    });
    return { blocked: false };
  }

  async listBlocked(userId: string) {
    const rows = await this.prisma.blockedUser.findMany({
      where: { userId },
      select: { blockedUser: { select: PUBLIC_USER_SELECT } },
    });
    return rows.map((r) => r.blockedUser);
  }

  async getBlockedUserIds(userId: string): Promise<Set<string>> {
    const rows = await this.prisma.blockedUser.findMany({
      where: { userId },
      select: { blockedUserId: true },
    });
    return new Set(rows.map((r) => r.blockedUserId));
  }

  async isBlocked(userId: string, otherUserId: string): Promise<boolean> {
    const row = await this.prisma.blockedUser.findUnique({
      where: {
        userId_blockedUserId: { userId, blockedUserId: otherUserId },
      },
    });
    return !!row;
  }

  async registerPushToken(userId: string, dto: RegisterPushTokenDto) {
    await this.prisma.pushToken.upsert({
      where: { userId_token: { userId, token: dto.token } },
      create: { userId, token: dto.token, platform: dto.platform },
      update: { platform: dto.platform },
    });
    return { ok: true };
  }

  async getUserPublic(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: PUBLIC_USER_SELECT,
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async updatePrivacy(userId: string, dto: UpdatePrivacyDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { privacySettings: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const current = (user.privacySettings as Record<string, unknown>) ?? {};
    const updated = { ...current, ...dto };

    return this.prisma.user.update({
      where: { id: userId },
      data: { privacySettings: updated },
      select: PUBLIC_USER_SELECT,
    });
  }
}
