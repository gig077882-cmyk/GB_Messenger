import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import type { AuthUser } from '../common/types/auth-user';
import { UsersService } from './users.service';
import {
  BlockUserDto,
  RegisterPushTokenDto,
  SearchUsersDto,
  SyncContactsDto,
  UpdatePrivacyDto,
  UpdateProfileDto,
} from './dto/users.dto';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  getMe(@CurrentUser() user: AuthUser) {
    return this.usersService.getProfile(user.id);
  }

  @Patch('me')
  updateMe(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateProfile(user.id, dto);
  }

  @Get('search')
  search(@CurrentUser() user: AuthUser, @Query() query: SearchUsersDto) {
    return this.usersService.search(user.id, query);
  }

  @Post('contacts/sync')
  syncContacts(@CurrentUser() user: AuthUser, @Body() dto: SyncContactsDto) {
    return this.usersService.syncContacts(user.id, dto);
  }

  @Get('contacts')
  listContacts(@CurrentUser() user: AuthUser) {
    return this.usersService.listContacts(user.id);
  }

  @Post('block')
  block(@CurrentUser() user: AuthUser, @Body() dto: BlockUserDto) {
    return this.usersService.blockUser(user.id, dto);
  }

  @Delete('block/:userId')
  unblock(@CurrentUser() user: AuthUser, @Param('userId') userId: string) {
    return this.usersService.unblockUser(user.id, userId);
  }

  @Get('blocked')
  listBlocked(@CurrentUser() user: AuthUser) {
    return this.usersService.listBlocked(user.id);
  }

  @Post('me/push')
  registerPush(
    @CurrentUser() user: AuthUser,
    @Body() dto: RegisterPushTokenDto,
  ) {
    return this.usersService.registerPushToken(user.id, dto);
  }

  @Get(':id')
  getUser(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.usersService.getUserPublic(id);
  }

  @Patch('me/privacy')
  updatePrivacy(@CurrentUser() user: AuthUser, @Body() dto: UpdatePrivacyDto) {
    return this.usersService.updatePrivacy(user.id, dto);
  }
}
