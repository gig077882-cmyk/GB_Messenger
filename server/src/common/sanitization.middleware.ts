import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

@Injectable()
export class SanitizationMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    if (req.body && typeof req.body === 'object') {
      this.sanitizeObject(req.body as Record<string, unknown>);
    }
    next();
  }

  private sanitizeObject(obj: Record<string, unknown>): void {
    for (const [key, value] of Object.entries(obj)) {
      if (typeof value === 'string') {
        obj[key] = this.sanitizeString(value);
      } else if (Array.isArray(value)) {
        value.forEach((v) => {
          if (typeof v === 'object' && v !== null) {
            this.sanitizeObject(v as Record<string, unknown>);
          }
        });
      } else if (value && typeof value === 'object') {
        this.sanitizeObject(value as Record<string, unknown>);
      }
    }
  }

  private sanitizeString(value: string): string {
    return value
      .replace(/[<>]/g, '')
      .replace(/javascript:/gi, '')
      .replace(/on\w+\s*=/gi, '')
      .trim();
  }
}
