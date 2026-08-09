import { Injectable, CanActivate, ExecutionContext, HttpException, HttpStatus } from '@nestjs/common';
import { RedisService } from '../redis/redis.service';
import { Request } from 'express';

interface BruteForceConfig {
  maxAttempts: number;
  lockoutMs: number;
  windowMs: number;
}

const BRUTE_FORCE_CONFIGS: Record<string, BruteForceConfig> = {
  login: { maxAttempts: 5, lockoutMs: 900_000, windowMs: 300_000 },
  register: { maxAttempts: 3, lockoutMs: 3600_000, windowMs: 3600_000 },
  refresh: { maxAttempts: 10, lockoutMs: 300_000, windowMs: 600_000 },
};

@Injectable()
export class BruteForceGuard implements CanActivate {
  constructor(private readonly redis: RedisService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request>();
    const ip = this.getClientIp(req);
    const path = req.path;
    
    let config = BRUTE_FORCE_CONFIGS.login;
    let keyPrefix = 'bruteforce:login';
    
    if (path.includes('/register')) {
      config = BRUTE_FORCE_CONFIGS.register;
      keyPrefix = 'bruteforce:register';
    } else if (path.includes('/refresh')) {
      config = BRUTE_FORCE_CONFIGS.refresh;
      keyPrefix = 'bruteforce:refresh';
    }

    const key = `${keyPrefix}:${ip}`;
    const lockKey = `${key}:locked`;

    const isLocked = await this.redis.get(lockKey);
    if (isLocked) {
      throw new HttpException(
        'Account locked due to too many attempts. Try again later.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const attempts = await this.redis.incr(key);
    if (attempts === 1) {
      await this.redis.expire(key, config.windowMs / 1000);
    }

    if (attempts > config.maxAttempts) {
      await this.redis.set(lockKey, '1', config.lockoutMs / 1000);
      await this.redis.del(key);
      throw new HttpException(
        'Too many attempts. Account locked.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    return true;
  }

  private getClientIp(req: Request): string {
    const forwarded = req.headers['x-forwarded-for'];
    if (forwarded) {
      return (typeof forwarded === 'string' ? forwarded : forwarded[0]).split(',')[0].trim();
    }
    return req.ip ?? req.socket.remoteAddress ?? 'unknown';
  }
}
