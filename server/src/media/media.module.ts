import { Module } from '@nestjs/common';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';
import { MediaProcessor } from './media.processor';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [RealtimeModule],
  controllers: [MediaController],
  providers: [MediaService, MediaProcessor],
  exports: [MediaService, MediaProcessor],
})
export class MediaModule {}
