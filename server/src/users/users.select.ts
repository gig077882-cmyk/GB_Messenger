import { Prisma } from '../generated/prisma/client';

export const PUBLIC_USER_SELECT = {
  id: true,
  email: true,
  displayName: true,
  username: true,
  bio: true,
  phone: true,
  avatarKey: true,
  avatarUrl: true,
  isOnline: true,
  lastSeenAt: true,
  wallpaperUrl: true,
} satisfies Prisma.UserSelect;

export type PublicUser = Prisma.UserGetPayload<{
  select: typeof PUBLIC_USER_SELECT;
}>;
