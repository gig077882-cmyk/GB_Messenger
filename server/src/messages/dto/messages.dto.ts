import {
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export const ALLOWED_MESSAGE_TYPES = [
  'TEXT',
  'IMAGE',
  'VIDEO',
  'AUDIO',
  'VOICE',
  'DOCUMENT',
] as const;

export class SendMessageDto {
  @IsOptional()
  @IsIn(ALLOWED_MESSAGE_TYPES)
  type?: (typeof ALLOWED_MESSAGE_TYPES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  text?: string;

  @IsOptional()
  @IsString()
  mediaKey?: string;

  @IsOptional()
  @IsString()
  mediaUrl?: string;

  @IsOptional()
  @IsObject()
  mediaMeta?: Record<string, unknown>;

  @IsOptional()
  @IsString()
  replyToId?: string;
}

export class ListMessagesQueryDto {
  @IsOptional()
  @IsString()
  cursor?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

export class EditMessageDto {
  @IsString()
  @MaxLength(4000)
  text!: string;
}

export class MessageReactionDto {
  @IsString()
  @MaxLength(8)
  emoji!: string;
}

export class ForwardMessageDto {
  @IsString({ each: true })
  messageIds!: string[];

  @IsString()
  targetChatId!: string;
}
