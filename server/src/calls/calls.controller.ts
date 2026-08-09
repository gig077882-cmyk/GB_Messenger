import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsString } from 'class-validator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import type { AuthUser } from '../common/types/auth-user';
import { CallsService } from './calls.service';

export class JoinTokenDto {
  @IsString()
  roomId!: string;
}

@ApiTags('calls')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('calls')
export class CallsController {
  constructor(private readonly callsService: CallsService) {}

  @Post('token')
  async joinToken(@CurrentUser() user: AuthUser, @Body() dto: JoinTokenDto) {
    const token = await this.callsService.getJoinToken(user.id, dto.roomId);
    return {
      token,
      serverUrl: process.env.LIVEKIT_URL ?? '',
    };
  }

  @Get('logs')
  logs(@CurrentUser() user: AuthUser) {
    return this.callsService.listLogs(user.id);
  }
}
