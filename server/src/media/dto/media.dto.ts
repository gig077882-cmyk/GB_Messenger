import { IsInt, IsMimeType, IsString, Max, Min } from 'class-validator';

export class PresignMediaDto {
  @IsString()
  fileName!: string;

  @IsMimeType()
  mimeType!: string;

  @IsInt()
  @Min(1)
  @Max(100 * 1024 * 1024)
  size!: number;
}
