import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ChatsModule } from './chats/chats.module';
import { MessagesModule } from './messages/messages.module';
import { RealtimeModule } from './realtime/realtime.module';
import { MediaModule } from './media/media.module';
import { StatusesModule } from './statuses/statuses.module';
import { CallsModule } from './calls/calls.module';
import { PushModule } from './push/push.module';
import { EncryptionService } from './common/encryption.service';
import { ConnectionLimiter } from './common/connection-limiter.service';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    RedisModule,
    AuthModule,
    UsersModule,
    ChatsModule,
    MessagesModule,
    RealtimeModule,
    MediaModule,
    StatusesModule,
    CallsModule,
    PushModule,
  ],
  controllers: [AppController],
  providers: [AppService, EncryptionService, ConnectionLimiter],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply((req, res, next) => {
        res.setHeader('X-Content-Type-Options', 'nosniff');
        res.setHeader('X-Frame-Options', 'DENY');
        res.setHeader('X-XSS-Protection', '1; mode=block');
        res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
        next();
      })
      .forRoutes('*');
  }
}
