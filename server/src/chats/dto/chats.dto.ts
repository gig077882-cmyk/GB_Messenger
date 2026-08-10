import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateDirectChatDto {
  @IsString()
  userId!: string;
}

export class CreateGroupDto {
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  name!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @IsString({ each: true })
  memberIds!: string[];

  @IsOptional()
  @IsString()
  avatarKey?: string;

  @IsOptional()
  @IsString()
  avatarUrl?: string;
}

export class UpdateChatDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  name?: string;

  @IsOptional()
  @IsString()
  avatarKey?: string;

  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @IsOptional()
  @IsString()
  wallpaperUrl?: string;
}

export class AddMemberDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @IsString({ each: true })
  userIds!: string[];
}

export class ToggleAdminDto {
  @IsString()
  userId!: string;

  @IsBoolean()
  isAdmin!: boolean;
}

export class UpdateMyMembershipDto {
  @IsOptional()
  @IsBoolean()
  isMuted?: boolean;

  @IsOptional()
  @IsString()
  lastReadMessageId?: string;
}

export class UpdateGroupSettingsDto {
  @IsOptional()
  @IsString()
  @MaxLength(64)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  description?: string;

  @IsOptional()
  @IsBoolean()
  onlyAdminsCanSend?: boolean;

  @IsOptional()
  @IsBoolean()
  onlyAdminsCanEdit?: boolean;
}
