import { Module } from '@nestjs/common';
import { MessagesController } from './messages.controller';
import { MessagesService } from './messages.service';
import { RealtimeModule } from '../realtime/realtime.module';
import { MediaModule } from '../media/media.module';
import { ChatsModule } from '../chats/chats.module';

@Module({
  imports: [RealtimeModule, MediaModule, ChatsModule],
  controllers: [MessagesController],
  providers: [MessagesService],
  exports: [MessagesService],
})
export class MessagesModule {}
