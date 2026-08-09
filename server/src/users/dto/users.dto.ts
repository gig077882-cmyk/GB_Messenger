import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  displayName?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[a-z0-9_]{3,32}$/, {
    message: 'username must be 3-32 chars: a-z, 0-9, _',
  })
  username?: string;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  bio?: string;

  @IsOptional()
  @IsString()
  @Matches(/^\+?[0-9]{10,15}$/, {
    message: 'phone must be 10-15 digits, optionally starting with +',
  })
  phone?: string;

  @IsOptional()
  @IsString()
  avatarKey?: string;

  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @IsOptional()
  @IsString()
  wallpaperUrl?: string;

  @IsOptional()
  @IsObject()
  privacySettings?: Record<string, unknown>;
}

export class SyncContactsDto {
  @IsArray()
  @ArrayMaxSize(10000)
  @IsString({ each: true })
  phones!: string[];
}

export class BlockUserDto {
  @IsString()
  userId!: string;
}

export class RegisterPushTokenDto {
  @IsString()
  token!: string;

  @IsString()
  platform!: string;

  @IsOptional()
  @IsString()
  deviceId?: string;
}

export class SearchUsersDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  q?: string;

  @IsOptional()
  @IsString()
  @Matches(/^\+?[0-9]+$/)
  phone?: string;
}

export class UpdatePrivacyDto {
  @IsOptional()
  @IsIn(['everyone', 'contacts', 'nobody'])
  lastSeen?: string;

  @IsOptional()
  @IsIn(['everyone', 'contacts', 'nobody'])
  profilePhoto?: string;

  @IsOptional()
  @IsIn(['everyone', 'contacts', 'nobody'])
  about?: string;

  @IsOptional()
  @IsBoolean()
  readReceipts?: boolean;
}
