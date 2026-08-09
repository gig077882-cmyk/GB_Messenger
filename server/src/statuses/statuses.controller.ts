import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import type { AuthUser } from '../common/types/auth-user';
import { StatusesService } from './statuses.service';
import { CreateStatusDto, StatusPrivacyDto, StatusReplyDto } from './dto/statuses.dto';

@ApiTags('statuses')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('statuses')
export class StatusesController {
  constructor(private readonly statusesService: StatusesService) {}

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateStatusDto) {
    return this.statusesService.create(user.id, dto);
  }

  @Get('feed')
  feed(@CurrentUser() user: AuthUser) {
    return this.statusesService.feed(user.id);
  }

  @Post(':id/view')
  view(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.statusesService.view(user.id, id);
  }

  @Delete(':id')
  remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.statusesService.remove(user.id, id);
  }

  @Post(':id/reply')
  reply(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: StatusReplyDto,
  ) {
    return this.statusesService.reply(user.id, id, dto);
  }

  @Patch(':id/privacy')
  updatePrivacy(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: StatusPrivacyDto,
  ) {
    return this.statusesService.updatePrivacy(user.id, id, dto);
  }
}
