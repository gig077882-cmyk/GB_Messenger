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
import { ChatsService } from './chats.service';
import {
  AddMemberDto,
  CreateDirectChatDto,
  CreateGroupDto,
  ToggleAdminDto,
  UpdateChatDto,
  UpdateGroupSettingsDto,
  UpdateMyMembershipDto,
} from './dto/chats.dto';

@ApiTags('chats')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('chats')
export class ChatsController {
  constructor(private readonly chatsService: ChatsService) {}

  @Post('direct')
  createDirect(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateDirectChatDto,
  ) {
    return this.chatsService.createDirect(user.id, dto);
  }

  @Post('group')
  createGroup(@CurrentUser() user: AuthUser, @Body() dto: CreateGroupDto) {
    return this.chatsService.createGroup(user.id, dto);
  }

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.chatsService.listChats(user.id);
  }

  @Get(':id')
  get(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.chatsService.getChat(user.id, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateChatDto,
  ) {
    return this.chatsService.updateChat(user.id, id, dto);
  }

  @Post(':id/members')
  addMember(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AddMemberDto,
  ) {
    return this.chatsService.addMember(user.id, id, dto);
  }

  @Delete(':id/members/:userId')
  removeMember(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('userId') userId: string,
  ) {
    return this.chatsService.removeMember(user.id, id, userId);
  }

  @Post(':id/admins')
  toggleAdmin(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ToggleAdminDto,
  ) {
    return this.chatsService.toggleAdmin(user.id, id, dto);
  }

  @Patch(':id/me')
  updateMe(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateMyMembershipDto,
  ) {
    return this.chatsService.updateMyMembership(user.id, id, dto);
  }

  @Delete(':id/leave')
  leave(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.chatsService.leaveChat(user.id, id);
  }

  @Post(':id/invite')
  generateInvite(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.chatsService.generateInviteLink(user.id, id);
  }

  @Get('by-invite/:code')
  joinByInvite(@CurrentUser() user: AuthUser, @Param('code') code: string) {
    return this.chatsService.joinByInviteLink(user.id, code);
  }

  @Patch(':id/settings')
  updateGroupSettings(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateGroupSettingsDto,
  ) {
    return this.chatsService.updateGroupSettings(user.id, id, dto);
  }
}
