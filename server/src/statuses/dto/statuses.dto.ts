import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateStatusDto {
  @IsOptional()
  @IsString()
  mediaKey?: string;

  @IsOptional()
  @IsString()
  mediaUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  caption?: string;

  @IsOptional()
  @IsString()
  mediaMeta?: string;

  @IsOptional()
  @IsIn(['IMAGE', 'VIDEO', 'TEXT'])
  kind?: 'IMAGE' | 'VIDEO' | 'TEXT';

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  text?: string;

  @IsOptional()
  @IsString()
  textColor?: string;

  @IsOptional()
  @IsString()
  bgColor?: string;

  @IsOptional()
  @IsString()
  fontStyle?: string;
}

export class StatusReplyDto {
  @IsString()
  @MaxLength(4000)
  text!: string;

  @IsOptional()
  @IsString()
  chatId?: string;
}

export class StatusPrivacyDto {
  @IsOptional()
  @IsIn(['everyone', 'contacts', 'nobody'])
  privacy?: string;
}
