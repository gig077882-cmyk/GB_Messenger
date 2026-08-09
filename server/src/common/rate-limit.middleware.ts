import { Injectable, NestMiddleware, HttpException, HttpStatus } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { RedisService } from '../redis/redis.service';

interface RateLimitConfig {
  windowMs: number;
  maxRequests: number;
}

const RATE_LIMITS: Record<string, RateLimitConfig> = {
  default: { windowMs: 60_000, maxRequests: 100 },
  auth: { windowMs: 900_000, maxRequests: 5 },
  api: { windowMs: 60_000, maxRequests: 60 },
  media: { windowMs: 60_000, maxRequests: 10 },
};

@Injectable()
export class RateLimitMiddleware implements NestMiddleware {
  constructor(private readonly redis: RedisService) {}

  async use(req: Request, res: Response, next: NextFunction) {
    const ip = this.getClientIp(req);
    const path = req.path;
    
    let config = RATE_LIMITS.default;
    if (path.includes('/auth/')) {
      config = RATE_LIMITS.auth;
    } else if (path.includes('/media/')) {
      config = RATE_LIMITS.media;
    } else if (path.includes('/api/')) {
      config = RATE_LIMITS.api;
    }

    const key = `ratelimit:${ip}:${path.split('/')[2] ?? 'default'}`;
    
    try {
      const current = await this.redis.incr(key);
      if (current === 1) {
        await this.redis.expire(key, config.windowMs / 1000);
      }

      const ttl = await this.redis.ttl(key);
      
      res.setHeader('X-RateLimit-Limit', config.maxRequests);
      res.setHeader('X-RateLimit-Remaining', Math.max(0, config.maxRequests - current));
      res.setHeader('X-RateLimit-Reset', ttl);

      if (current > config.maxRequests) {
        throw new HttpException(
          'Too many requests',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      next();
    } catch (err) {
      if (err instanceof HttpException) throw err;
      next();
    }
  }

  private getClientIp(req: Request): string {
    const forwarded = req.headers['x-forwarded-for'];
    if (forwarded) {
      return (typeof forwarded === 'string' ? forwarded : forwarded[0]).split(',')[0].trim();
    }
    return req.ip ?? req.socket.remoteAddress ?? 'unknown';
  }
}
