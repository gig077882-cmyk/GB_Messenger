import {
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AccessToken } from 'livekit-server-sdk';
import { PrismaService } from '../prisma/prisma.service';
import type { CallType, CallStatus } from '../generated/prisma/enums';

export interface CallInvitePayload {
  callId: string;
  chatId: string;
  roomId: string;
  type: CallType;
  initiator: { id: string; displayName: string };
  token: string;
  serverUrl: string;
}

@Injectable()
export class CallsService {
  private readonly logger = new Logger(CallsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Create a call log entry + LiveKit token for the initiator.
   * Returns null if the user is not a chat member.
   */
  async startCall(
    userId: string,
    chatId: string,
    type: CallType,
  ): Promise<CallInvitePayload | null> {
    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId, userId } },
      include: { user: { select: { displayName: true } } },
    });
    if (!member) return null;

    const call = await this.prisma.callLog.create({
      data: { chatId, initiatorId: userId, type, status: 'ONGOING' },
    });

    const roomId = `call-${call.id}`;
    await this.prisma.callLog.update({
      where: { id: call.id },
      data: { roomId },
    });
    const token = await this.issueToken(userId, roomId);

    return {
      callId: call.id,
      chatId,
      roomId,
      type,
      initiator: { id: userId, displayName: member.user.displayName },
      token,
      serverUrl: this.config.get<string>('LIVEKIT_URL') ?? '',
    };
  }

  async endCall(
    userId: string,
    callId: string,
    status: CallStatus = 'COMPLETED',
  ): Promise<{ id: string; chatId: string; status: CallStatus } | null> {
    const call = await this.prisma.callLog.findUnique({
      where: { id: callId },
    });
    if (!call) return null;

    const isMember = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: call.chatId, userId } },
    });
    if (!isMember) return null;

    const updated = await this.prisma.callLog.update({
      where: { id: callId },
      data: { status, endedAt: new Date() },
    });
    return { id: updated.id, chatId: updated.chatId, status: updated.status };
  }

  /** Issue a LiveKit access token for the given room. */
  async issueToken(userId: string, roomId: string): Promise<string> {
    const apiKey = this.config.get<string>('LIVEKIT_API_KEY') ?? 'devkey';
    const apiSecret =
      this.config.get<string>('LIVEKIT_API_SECRET') ?? 'devsecret';

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { displayName: true },
    });

    const token = new AccessToken(apiKey, apiSecret, {
      identity: userId,
      name: user?.displayName ?? userId,
      ttl: '4h',
    });
    token.addGrant({ roomJoin: true, room: roomId });
    return token.toJwt();
  }

  /** REST endpoint: get a token to join an ongoing call room. */
  async getJoinToken(userId: string, roomId: string): Promise<string> {
    if (!roomId.startsWith('call-')) {
      throw new NotFoundException('Call room not found');
    }
    const call = await this.prisma.callLog.findUnique({
      where: { id: roomId.slice(5) },
    });
    if (!call || call.status !== 'ONGOING') {
      throw new ForbiddenException('Call is not active');
    }
    const member = await this.prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: call.chatId, userId } },
    });
    if (!member) throw new ForbiddenException('Not a chat member');
    return this.issueToken(userId, roomId);
  }

  async listLogs(userId: string): Promise<unknown[]> {
    const memberships = await this.prisma.chatMember.findMany({
      where: { userId },
      select: { chatId: true },
    });
    const logs = await this.prisma.callLog.findMany({
      where: { chatId: { in: memberships.map((m) => m.chatId) } },
      orderBy: { startedAt: 'desc' },
      take: 50,
      include: {
        initiator: { select: { id: true, displayName: true, avatarUrl: true } },
      },
    });
    return logs;
  }
}
