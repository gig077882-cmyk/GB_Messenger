import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Queue, Worker } from 'bullmq';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { MediaService } from './media.service';
import { Prisma } from '../generated/prisma/client';

const execFileAsync = promisify(execFile);

export interface MediaJob {
  messageId: string;
  chatId: string;
  mediaKey: string;
  mediaUrl: string;
  type: 'IMAGE' | 'VIDEO' | 'AUDIO' | 'VOICE';
}

const WAVEFORM_BUCKETS = 150;

const COMPRESSION = {
  IMAGE: { maxWidth: 1280, quality: 5 },
  VIDEO: { maxWidth: 720, crf: 28, preset: 'fast' },
  AUDIO: { bitrate: '64k', codec: 'libopus' },
};

/**
 * Background media processing (BullMQ + ffmpeg):
 *  - IMAGE/VIDEO: generate thumbnail + compress
 *  - AUDIO/VOICE: extract waveform + compress
 * Gracefully skips when ffmpeg or Redis is unavailable.
 */
@Injectable()
export class MediaProcessor implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MediaProcessor.name);
  private queue: Queue<MediaJob> | null = null;
  private worker: Worker<MediaJob> | null = null;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
    private readonly media: MediaService,
  ) {}

  onModuleInit(): void {
    const redisUrl = this.config.get<string>('REDIS_URL');
    if (!redisUrl) return;

    try {
      this.queue = new Queue<MediaJob>('media-processing', {
        connection: { url: redisUrl },
      });
      this.worker = new Worker<MediaJob>(
        'media-processing',
        async (job) => this.process(job.data),
        { connection: { url: redisUrl }, concurrency: 2 },
      );
      this.worker.on('failed', (job, err) => {
        this.logger.warn(`media job ${job?.id} failed: ${err.message}`);
      });
      this.logger.log('Media worker started');
    } catch (err) {
      this.logger.warn(`Media worker init failed: ${(err as Error).message}`);
    }
  }

  async enqueue(job: MediaJob): Promise<void> {
    if (!this.queue) return;
    try {
      await this.queue.add('process', job, {
        attempts: 2,
        backoff: { type: 'exponential', delay: 5000 },
        removeOnComplete: 100,
        removeOnFail: 1000,
      });
    } catch (err) {
      this.logger.warn(`Enqueue failed: ${(err as Error).message}`);
    }
  }

  private async process(job: MediaJob): Promise<void> {
    const meta: Record<string, unknown> = {};

    if (job.type === 'IMAGE') {
      meta.compressedKey = await this.compressImage(job);
      meta.thumbnailKey = await this.makeThumbnail(job);
      if (meta.thumbnailKey) {
        meta.thumbnailUrl = this.media.publicUrl(meta.thumbnailKey as string);
      }
    }

    if (job.type === 'VIDEO') {
      meta.compressedKey = await this.compressVideo(job);
      meta.thumbnailKey = await this.makeThumbnail(job);
      if (meta.thumbnailKey) {
        meta.thumbnailUrl = this.media.publicUrl(meta.thumbnailKey as string);
      }
    }

    if (job.type === 'AUDIO' || job.type === 'VOICE') {
      meta.compressedKey = await this.compressAudio(job);
      meta.waveform = await this.makeWaveform(job);
    }

    if (Object.keys(meta).length > 0) {
      await this.prisma.message.update({
        where: { id: job.messageId },
        data: { mediaMeta: meta as Prisma.InputJsonValue },
      });
      this.realtime.emitToChat(job.chatId, 'message:update', {
        chatId: job.chatId,
        messageId: job.messageId,
        mediaMeta: meta,
      });
    }
  }

  private async compressImage(job: MediaJob): Promise<string | null> {
    const input = job.mediaUrl;
    if (!input) return null;
    const compressedKey = `compressed/${job.mediaKey.replace(/^u\//, '')}.jpg`;
    const tmpFile = `${this.config.get<string>('TMP_DIR') ?? 'tmp'}\\compressed_${job.messageId}.jpg`;

    const args = [
      '-i',
      input,
      '-vf',
      `scale=${COMPRESSION.IMAGE.maxWidth}:-2`,
      '-q:v',
      String(COMPRESSION.IMAGE.quality),
      '-y',
      tmpFile,
    ];

    try {
      await execFileAsync('ffmpeg', args, {
        timeout: 30_000,
        maxBuffer: 4 * 1024 * 1024,
      });
      const client = await this.importMinio();
      if (!client) return null;
      await client.fPutObject(this.bucketName, compressedKey, tmpFile);
      return compressedKey;
    } catch (err) {
      this.logger.debug(
        `image compression skipped: ${(err as Error).message}`,
      );
      return null;
    }
  }

  private async compressVideo(job: MediaJob): Promise<string | null> {
    const input = job.mediaUrl;
    if (!input) return null;
    const compressedKey = `compressed/${job.mediaKey.replace(/^u\//, '')}.mp4`;
    const tmpFile = `${this.config.get<string>('TMP_DIR') ?? 'tmp'}\\compressed_${job.messageId}.mp4`;

    const args = [
      '-i',
      input,
      '-vf',
      `scale=${COMPRESSION.VIDEO.maxWidth}:-2`,
      '-c:v',
      'libx264',
      '-crf',
      String(COMPRESSION.VIDEO.crf),
      '-preset',
      COMPRESSION.VIDEO.preset,
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-y',
      tmpFile,
    ];

    try {
      await execFileAsync('ffmpeg', args, {
        timeout: 120_000,
        maxBuffer: 16 * 1024 * 1024,
      });
      const client = await this.importMinio();
      if (!client) return null;
      await client.fPutObject(this.bucketName, compressedKey, tmpFile);
      return compressedKey;
    } catch (err) {
      this.logger.debug(
        `video compression skipped: ${(err as Error).message}`,
      );
      return null;
    }
  }

  private async compressAudio(job: MediaJob): Promise<string | null> {
    const input = job.mediaUrl;
    if (!input) return null;
    const compressedKey = `compressed/${job.mediaKey.replace(/^u\//, '')}.opus`;
    const tmpFile = `${this.config.get<string>('TMP_DIR') ?? 'tmp'}\\compressed_${job.messageId}.opus`;

    const args = [
      '-i',
      input,
      '-c:a',
      COMPRESSION.AUDIO.codec,
      '-b:a',
      COMPRESSION.AUDIO.bitrate,
      '-y',
      tmpFile,
    ];

    try {
      await execFileAsync('ffmpeg', args, {
        timeout: 60_000,
        maxBuffer: 8 * 1024 * 1024,
      });
      const client = await this.importMinio();
      if (!client) return null;
      await client.fPutObject(this.bucketName, compressedKey, tmpFile);
      return compressedKey;
    } catch (err) {
      this.logger.debug(
        `audio compression skipped: ${(err as Error).message}`,
      );
      return null;
    }
  }

  private async makeThumbnail(job: MediaJob): Promise<string | null> {
    const input = job.mediaUrl;
    if (!input) return null;
    const thumbKey = `thumbs/${job.mediaKey.replace(/^u\//, '')}.jpg`;
    const tmpFile = `${this.config.get<string>('TMP_DIR') ?? 'tmp'}\\${job.messageId}.jpg`;

    const args =
      job.type === 'VIDEO'
        ? [
            '-ss',
            '0.5',
            '-i',
            input,
            '-frames:v',
            '1',
            '-vf',
            'scale=360:-2',
            '-y',
            tmpFile,
          ]
        : ['-i', input, '-vf', 'scale=360:-2', '-y', tmpFile];

    try {
      await execFileAsync('ffmpeg', args, {
        timeout: 30_000,
        maxBuffer: 4 * 1024 * 1024,
      });
      const client = await this.importMinio();
      if (!client) return null;
      await client.fPutObject(this.bucketName, thumbKey, tmpFile);
      return thumbKey;
    } catch (err) {
      this.logger.debug(
        `thumbnail skipped (ffmpeg unavailable?): ${(err as Error).message}`,
      );
      return null;
    }
  }

  private async makeWaveform(job: MediaJob): Promise<number[] | null> {
    const input = job.mediaUrl;
    if (!input) return null;

    try {
      const { stdout } = await execFileAsync(
        'ffmpeg',
        ['-i', input, '-ac', '1', '-ar', '16000', '-f', 's16le', '-'],
        {
          timeout: 60_000,
          maxBuffer: 64 * 1024 * 1024,
          encoding: 'buffer' as const,
        },
      );
      const samplesBuf = stdout as Buffer;
      const samples = new Int16Array(
        samplesBuf.buffer,
        samplesBuf.byteOffset,
        samplesBuf.byteLength / 2,
      );
      const bucketSize = Math.max(
        1,
        Math.floor(samples.length / WAVEFORM_BUCKETS),
      );
      const waveform: number[] = [];

      for (let i = 0; i < WAVEFORM_BUCKETS; i++) {
        let max = 0;
        const start = i * bucketSize;
        const end = Math.min(samples.length, start + bucketSize);
        for (let j = start; j < end; j++) {
          const v = Math.abs(samples[j]) / 32768;
          if (v > max) max = v;
        }
        waveform.push(Math.max(1, Math.round(max * 100)));
      }
      return waveform;
    } catch (err) {
      this.logger.debug(`waveform skipped: ${(err as Error).message}`);
      return null;
    }
  }

  private get bucketName(): string {
    return this.config.get<string>('MINIO_BUCKET') ?? 'gb-media';
  }

  private async importMinio() {
    try {
      const { Client } = await import('minio');
      return new Client({
        endPoint: this.config.get<string>('MINIO_ENDPOINT') ?? 'localhost',
        port: parseInt(this.config.get<string>('MINIO_PORT') ?? '9000', 10),
        useSSL: this.config.get<string>('MINIO_USE_SSL') === 'true',
        accessKey: this.config.get<string>('MINIO_ACCESS_KEY') ?? 'minioadmin',
        secretKey: this.config.get<string>('MINIO_SECRET_KEY') ?? 'minioadmin',
      });
    } catch {
      return null;
    }
  }

  onModuleDestroy(): void {
    void this.worker?.close();
    void this.queue?.close();
  }
}
