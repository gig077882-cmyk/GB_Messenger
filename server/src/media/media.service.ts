import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client } from 'minio';
import * as crypto from 'crypto';
import type { PresignMediaDto } from './dto/media.dto';

const MAX_FILE_SIZE = 100 * 1024 * 1024; // 100 MB
const ALLOWED_MIME = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/heic',
  'video/mp4',
  'video/webm',
  'video/quicktime',
  'video/3gpp',
  'video/x-msvideo',
  'audio/mpeg',
  'audio/mp4',
  'audio/ogg',
  'audio/wav',
  'audio/aac',
  'audio/webm',
  'application/pdf',
  'application/zip',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain',
  'application/octet-stream',
]);

@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);
  private client: Client | null = null;

  constructor(private readonly config: ConfigService) {}

  async presignUpload(
    userId: string,
    dto: PresignMediaDto,
  ): Promise<{
    key: string;
    uploadUrl: string;
    downloadUrl: string;
    expiresIn: number;
  }> {
    if (!ALLOWED_MIME.has(dto.mimeType)) {
      throw new BadRequestException(`Unsupported mime type: ${dto.mimeType}`);
    }
    if (dto.size > MAX_FILE_SIZE) {
      throw new BadRequestException('File too large (max 100 MB)');
    }

    const client = await this.getClient();
    const ext = this.extFromMime(dto.mimeType);
    const safeName = dto.fileName.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 80);
    const key = `u/${userId}/${crypto.randomUUID()}/${safeName}${ext}`;
    const expiresIn = 15 * 60;

    try {
      const uploadUrl = await client.presignedPutObject(
        this.bucket,
        key,
        expiresIn,
      );
      return {
        key,
        uploadUrl,
        downloadUrl: this.publicUrl(key),
        expiresIn,
      };
    } catch (err) {
      this.logger.error(`presign failed: ${(err as Error).message}`);
      throw new ServiceUnavailableException('Media storage unavailable');
    }
  }

  publicUrl(key: string): string {
    const base = this.config.get<string>('MINIO_PUBLIC_BASE_URL') ?? '';
    return `${base}/${key}`;
  }

  compressedUrl(compressedKey: string): string {
    const base = this.config.get<string>('MINIO_PUBLIC_BASE_URL') ?? '';
    return `${base}/${compressedKey}`;
  }

  private get bucket(): string {
    return this.config.get<string>('MINIO_BUCKET') ?? 'gb-media';
  }

  private async getClient(): Promise<Client> {
    if (this.client) return this.client;

    const endpoint = this.config.get<string>('MINIO_ENDPOINT') ?? 'localhost';
    const port = parseInt(this.config.get<string>('MINIO_PORT') ?? '9000', 10);
    const useSsl = this.config.get<string>('MINIO_USE_SSL') === 'true';

    this.client = new Client({
      endPoint: endpoint,
      port,
      useSSL: useSsl,
      accessKey: this.config.get<string>('MINIO_ACCESS_KEY') ?? 'minioadmin',
      secretKey: this.config.get<string>('MINIO_SECRET_KEY') ?? 'minioadmin',
    });

    const exists = await this.client.bucketExists(this.bucket);
    if (!exists) {
      await this.client.makeBucket(this.bucket);
    }
    await this.client.setBucketPolicy(
      this.bucket,
      JSON.stringify({
        Version: '2012-10-17',
        Statement: [
          {
            Effect: 'Allow',
            Principal: { AWS: ['*'] },
            Action: ['s3:GetObject'],
            Resource: [`arn:aws:s3:::${this.bucket}/*`],
          },
        ],
      }),
    );
    return this.client;
  }

  private extFromMime(mime: string): string {
    const map: Record<string, string> = {
      'image/jpeg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp',
      'image/gif': '.gif',
      'image/heic': '.heic',
      'video/mp4': '.mp4',
      'video/webm': '.webm',
      'video/quicktime': '.mov',
      'video/3gpp': '.3gp',
      'audio/mpeg': '.mp3',
      'audio/mp4': '.m4a',
      'audio/ogg': '.ogg',
      'audio/wav': '.wav',
      'audio/aac': '.aac',
      'audio/webm': '.weba',
      'application/pdf': '.pdf',
      'application/zip': '.zip',
      'text/plain': '.txt',
    };
    return map[mime] ?? '';
  }
}
