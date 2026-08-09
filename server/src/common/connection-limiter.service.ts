import { Injectable } from '@nestjs/common';
import { RedisService } from '../redis/redis.service';

@Injectable()
export class ConnectionLimiter {
  private readonly maxConnectionsPerIp = 5;
  private readonly maxConnectionsPerUser = 3;

  constructor(private readonly redis: RedisService) {}

  async checkIpLimit(ip: string): Promise<boolean> {
    const key = `ws:connections:ip:${ip}`;
    const count = await this.redis.incr(key);
    if (count === 1) {
      await this.redis.expire(key, 3600);
    }
    return count <= this.maxConnectionsPerIp;
  }

  async checkUserLimit(userId: string): Promise<boolean> {
    const key = `ws:connections:user:${userId}`;
    const count = await this.redis.incr(key);
    if (count === 1) {
      await this.redis.expire(key, 3600);
    }
    return count <= this.maxConnectionsPerUser;
  }

  async decrementIp(ip: string): Promise<void> {
    const key = `ws:connections:ip:${ip}`;
    await this.redis.decr(key);
  }

  async decrementUser(userId: string): Promise<void> {
    const key = `ws:connections:user:${userId}`;
    await this.redis.decr(key);
  }

  async getIpConnections(ip: string): Promise<number> {
    const count = await this.redis.get(`ws:connections:ip:${ip}`);
    return parseInt(count ?? '0', 10);
  }

  async getUserConnections(userId: string): Promise<number> {
    const count = await this.redis.get(`ws:connections:user:${userId}`);
    return parseInt(count ?? '0', 10);
  }
}
