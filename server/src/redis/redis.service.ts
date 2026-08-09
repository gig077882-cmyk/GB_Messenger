import {
  Injectable,
  Logger,
  OnModuleDestroy,
  Optional,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Redis } from 'ioredis';

/**
 * Redis wrapper. Lazy connection: falls back to an in-memory store
 * when Redis is unreachable, so the API keeps working in dev mode.
 */
@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis | null = null;
  private memory = new Map<string, string>();
  private readonly memoryTtl = new Map<string, number>();
  private readonly fallbackTtlMs = 60 * 60 * 1000;

  constructor(@Optional() private readonly config?: ConfigService) {}

  onModuleInit(): void {
    if (!this.config) return;
    this.tryConnect();
  }

  private tryConnect(): void {
    const url = this.config?.get<string>('REDIS_URL');
    if (!url) return;
    try {
      this.client = new Redis(url, {
        lazyConnect: true,
        maxRetriesPerRequest: 1,
        retryStrategy: (times) => Math.min(times * 500, 5000),
      });
      this.client.on('error', (err) => {
        this.logger.warn(
          `Redis error (falling back to memory): ${err.message}`,
        );
      });
      this.client.connect().catch(() => {
        this.logger.warn('Redis unavailable, using in-memory fallback');
      });
    } catch {
      this.logger.warn('Redis init failed, using in-memory fallback');
    }
  }

  private get isMemory(): boolean {
    return !this.client || this.client.status !== 'ready';
  }

  private memSet(key: string, value: string, ttlSeconds?: number): void {
    this.memory.set(key, value);
    if (ttlSeconds) {
      this.memoryTtl.set(key, Date.now() + ttlSeconds * 1000);
    }
  }

  private memGet(key: string): string | undefined {
    const expiry = this.memoryTtl.get(key);
    if (expiry && expiry < Date.now()) {
      this.memory.delete(key);
      this.memoryTtl.delete(key);
      return undefined;
    }
    return this.memory.get(key);
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (!this.isMemory) {
      if (ttlSeconds) await this.client!.set(key, value, 'EX', ttlSeconds);
      else await this.client!.set(key, value);
      return;
    }
    this.memSet(key, value, ttlSeconds);
  }

  async get(key: string): Promise<string | undefined> {
    if (!this.isMemory) return (await this.client!.get(key)) ?? undefined;
    return this.memGet(key);
  }

  async del(...keys: string[]): Promise<void> {
    if (!this.isMemory) {
      await this.client!.del(...keys);
      return;
    }
    for (const k of keys) {
      this.memory.delete(k);
      this.memoryTtl.delete(k);
    }
  }

  async sadd(key: string, member: string, ttlSeconds?: number): Promise<void> {
    if (!this.isMemory) {
      await this.client!.sadd(key, member);
      if (ttlSeconds) await this.client!.expire(key, ttlSeconds);
      return;
    }
    const members = this.memGet(key);
    const set = new Set(members ? members.split(',') : []);
    set.add(member);
    this.memSet(key, [...set].join(','), ttlSeconds);
  }

  async srem(key: string, member: string): Promise<void> {
    if (!this.isMemory) {
      await this.client!.srem(key, member);
      return;
    }
    const members = this.memGet(key);
    if (!members) return;
    const set = new Set(members.split(','));
    set.delete(member);
    if (set.size === 0) this.memory.delete(key);
    else this.memSet(key, [...set].join(','));
  }

  async scard(key: string): Promise<number> {
    if (!this.isMemory) return this.client!.scard(key);
    const members = this.memGet(key);
    return members ? members.split(',').filter(Boolean).length : 0;
  }

  async incr(key: string): Promise<number> {
    if (!this.isMemory) return this.client!.incr(key);
    const val = parseInt(this.memGet(key) ?? '0', 10);
    const newVal = val + 1;
    this.memory.set(key, String(newVal));
    return newVal;
  }

  async decr(key: string): Promise<number> {
    if (!this.isMemory) return this.client!.decr(key);
    const val = parseInt(this.memGet(key) ?? '0', 10);
    const newVal = Math.max(0, val - 1);
    this.memory.set(key, String(newVal));
    return newVal;
  }

  async expire(key: string, seconds: number): Promise<void> {
    if (!this.isMemory) {
      await this.client!.expire(key, seconds);
      return;
    }
    this.memoryTtl.set(key, Date.now() + seconds * 1000);
  }

  async ttl(key: string): Promise<number> {
    if (!this.isMemory) return this.client!.ttl(key);
    const expiry = this.memoryTtl.get(key);
    if (!expiry) return -1;
    return Math.max(0, Math.floor((expiry - Date.now()) / 1000));
  }

  async publish(channel: string, message: string): Promise<void> {
    if (!this.isMemory) {
      await this.client!.publish(channel, message);
      return;
    }
    this.logger.debug(`pub (memory): ${channel}`);
  }

  getRedisClient(): Redis | null {
    return this.isMemory ? null : this.client;
  }

  onModuleDestroy(): void {
    this.client?.disconnect();
  }
}
