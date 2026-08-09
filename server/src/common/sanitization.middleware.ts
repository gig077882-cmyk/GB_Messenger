import { Injectable, NestMiddleware, HttpException, HttpStatus } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

@Injectable()
export class SanitizationMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    if (req.body && typeof req.body === 'object') {
      req.body = this.sanitizeObject(req.body);
    }
    if (req.query && typeof req.query === 'object') {
      req.query = this.sanitizeObject(req.query);
    }
    if (req.params && typeof req.params === 'object') {
      req.params = this.sanitizeObject(req.params);
    }
    next();
  }

  private sanitizeObject(obj: Record<string, unknown>): Record<string, unknown> {
    const sanitized: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(obj)) {
      sanitized[key] = this.sanitizeValue(value);
    }
    return sanitized;
  }

  private sanitizeValue(value: unknown): unknown {
    if (typeof value === 'string') {
      return this.sanitizeString(value);
    }
    if (Array.isArray(value)) {
      return value.map((v) => this.sanitizeValue(v));
    }
    if (value && typeof value === 'object') {
      return this.sanitizeObject(value as Record<string, unknown>);
    }
    return value;
  }

  private sanitizeString(value: string): string {
    return value
      .replace(/[<>]/g, '')
      .replace(/javascript:/gi, '')
      .replace(/on\w+\s*=/gi, '')
      .trim();
  }
}
