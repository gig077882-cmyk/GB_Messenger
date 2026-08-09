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
import { MessagesService } from './messages.service';
import {
  EditMessageDto,
  ListMessagesQueryDto,
  SendMessageDto,
  ForwardMessageDto,
  MessageReactionDto,
} from './dto/messages.dto';

@ApiTags('messages')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Get('chats/:chatId/messages')
  list(
    @CurrentUser() user: AuthUser,
    @Param('chatId') chatId: string,
    @Query() query: ListMessagesQueryDto,
  ) {
    return this.messagesService.listMessages(user.id, chatId, query);
  }

  @Post('chats/:chatId/messages')
  send(
    @CurrentUser() user: AuthUser,
    @Param('chatId') chatId: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.messagesService.sendMessage(user.id, chatId, dto);
  }

  @Patch('messages/:id')
  edit(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: EditMessageDto,
  ) {
    return this.messagesService.editMessage(user.id, id, dto);
  }

  @Delete('messages/:id')
  remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.messagesService.deleteMessage(user.id, id);
  }

  @Post('messages/:id/reactions')
  addReaction(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: MessageReactionDto,
  ) {
    return this.messagesService.addReaction(user.id, id, dto);
  }

  @Delete('messages/:id/reactions')
  removeReaction(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.messagesService.removeReaction(user.id, id);
  }

  @Get('messages/:id/info')
  info(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.messagesService.messageInfo(user.id, id);
  }

  @Post('messages/forward')
  forward(@CurrentUser() user: AuthUser, @Body() dto: ForwardMessageDto) {
    return this.messagesService.forwardMessage(user.id, dto);
  }

  @Get('chats/:chatId/search')
  search(
    @CurrentUser() user: AuthUser,
    @Param('chatId') chatId: string,
    @Query('q') q: string,
  ) {
    return this.messagesService.searchMessages(user.id, chatId, q);
  }
}
