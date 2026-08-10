import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import type { StringValue } from 'ms';
import { PrismaService } from '../prisma/prisma.service';
import type { JwtPayload } from './strategies/jwt.strategy';
import type {
  LoginDto,
  LogoutDto,
  RefreshDto,
  RegisterDto,
} from './dto/auth.dto';

interface SessionDeviceInfo {
  deviceId?: string;
  fcmToken?: string;
  platform?: string;
}

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    email: string;
    displayName: string;
    username: string | null;
    avatarUrl: string | null;
  };
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthResult> {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });
    if (existing) throw new ConflictException('Email already registered');

    if (dto.username) {
      const taken = await this.prisma.user.findUnique({
        where: { username: dto.username },
      });
      if (taken) throw new ConflictException('Username already taken');
    }

    if (dto.phone) {
      const phoneTaken = await this.prisma.user.findUnique({
        where: { phone: dto.phone },
      });
      if (phoneTaken)
        throw new ConflictException('Phone number already registered');
    }

    const passwordHash = await argon2.hash(dto.password);
    const user = await this.prisma.user.create({
      data: {
        email: dto.email.toLowerCase(),
        passwordHash,
        displayName: dto.displayName,
        username: dto.username ?? null,
        phone: dto.phone ?? null,
      },
    });

    return this.issueTokens(
      user.id,
      user.email,
      user.displayName,
      user.username,
      dto,
    );
  }

  async login(dto: LoginDto): Promise<AuthResult> {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });
    if (!user) throw new UnauthorizedException('Invalid credentials');

    const valid = await argon2.verify(user.passwordHash, dto.password);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    return this.issueTokens(
      user.id,
      user.email,
      user.displayName,
      user.username,
      dto,
    );
  }

  async refresh(dto: RefreshDto): Promise<AuthResult> {
    const payload = this.verifyRefreshToken(dto.refreshToken);

    const session = await this.prisma.session.findFirst({
      where: {
        userId: payload.sub,
        ...(dto.deviceId ? { deviceId: dto.deviceId } : {}),
      },
      include: { user: true },
    });
    if (!session) throw new UnauthorizedException('Session not found');

    const hashMatches = await argon2.verify(
      session.refreshTokenHash,
      dto.refreshToken,
    );
    if (!hashMatches) throw new UnauthorizedException('Invalid refresh token');

    const user = session.user;
    return this.issueTokens(
      user.id,
      user.email,
      user.displayName,
      user.username,
      {
        deviceId: session.deviceId,
        fcmToken: session.fcmToken ?? undefined,
        platform: session.platform ?? undefined,
      },
    );
  }

  async logout(dto: LogoutDto): Promise<void> {
    if (!dto.refreshToken) return;
    try {
      const payload = this.verifyRefreshToken(dto.refreshToken);
      await this.prisma.session.deleteMany({
        where: {
          refreshTokenHash: await argon2.hash(dto.refreshToken),
          userId: payload.sub,
        },
      });
    } catch {
      // token already invalid - nothing to do
    }
  }

  private verifyRefreshToken(token: string): JwtPayload {
    try {
      const payload = this.jwt.verify<JwtPayload>(token, {
        secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
      });
      if (payload.type !== 'refresh') throw new Error('wrong type');
      return payload;
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  private async issueTokens(
    userId: string,
    email: string,
    displayName: string,
    username: string | null,
    device: SessionDeviceInfo,
  ): Promise<AuthResult> {
    const accessToken = this.jwt.sign(
      { sub: userId, email, type: 'access' },
      {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
        expiresIn: (this.config.get<string>('JWT_ACCESS_TTL') ??
          '15m') as StringValue,
      },
    );
    const refreshToken = this.jwt.sign(
      { sub: userId, email, type: 'refresh' },
      {
        secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
        expiresIn: (this.config.get<string>('JWT_REFRESH_TTL') ??
          '30d') as StringValue,
      },
    );

    if (device.deviceId) {
      const refreshTokenHash = await argon2.hash(refreshToken);
      await this.prisma.session.upsert({
        where: {
          userId_deviceId: { userId, deviceId: device.deviceId },
        },
        create: {
          userId,
          deviceId: device.deviceId,
          refreshTokenHash,
          fcmToken: device.fcmToken ?? null,
          platform: device.platform ?? null,
        },
        update: {
          refreshTokenHash,
          fcmToken: device.fcmToken ?? undefined,
          platform: device.platform ?? undefined,
          lastActiveAt: new Date(),
        },
      });
    }

    return {
      accessToken,
      refreshToken,
      user: {
        id: userId,
        email,
        displayName,
        username,
        avatarUrl: null,
      },
    };
  }
}
