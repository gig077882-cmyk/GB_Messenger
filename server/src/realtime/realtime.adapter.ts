import { ConfigService } from '@nestjs/config';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import type { Server, ServerOptions, Socket } from 'socket.io';
import { Redis } from 'ioredis';
import type { JwtPayload } from '../auth/strategies/jwt.strategy';
import { JwtService } from '@nestjs/jwt';

/**
 * Socket.IO adapter with:
 *  - Redis pub/sub adapter (horizontal scaling)
 *  - JWT handshake verification
 */
export class RedisIoAdapter extends IoAdapter {
  constructor(
    app: object,
    private readonly config: ConfigService,
    private readonly jwtService: JwtService,
  ) {
    super(app);
  }

  createIOServer(port: number, options?: ServerOptions): Server {
    const server = super.createIOServer(port, options) as Server;

    const redisUrl = this.config.get<string>('REDIS_URL');
    if (redisUrl) {
      try {
        const pubClient = new Redis(redisUrl);
        const subClient = pubClient.duplicate();
        pubClient.on('error', () => undefined);
        subClient.on('error', () => undefined);
        server.adapter(createAdapter(pubClient, subClient));
      } catch {
        // Redis adapter unavailable - fall back to in-memory adapter
      }
    }

    server.use((socket: Socket, next: (err?: Error) => void) => {
      const auth = socket.handshake.auth as { token?: unknown } | undefined;
      const token =
        (typeof auth?.token === 'string' ? auth.token : undefined) ??
        (socket.handshake.headers.authorization?.startsWith('Bearer ')
          ? socket.handshake.headers.authorization.slice(7)
          : undefined);

      if (!token) {
        return next(new Error('unauthorized'));
      }

      try {
        const payload = this.jwtService.verify<JwtPayload>(token, {
          secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
        });
        if (payload.type !== 'access') return next(new Error('unauthorized'));
        (socket.data as { user: { id: string; email: string } }).user = {
          id: payload.sub,
          email: payload.email,
        };
        next();
      } catch {
        next(new Error('unauthorized'));
      }
    });

    return server;
  }
}
