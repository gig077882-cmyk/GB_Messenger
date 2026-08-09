import { ValidationPipe, Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { RedisIoAdapter } from './realtime/realtime.adapter';
import { JwtService } from '@nestjs/jwt';
import { RateLimitMiddleware } from './common/rate-limit.middleware';
import { SanitizationMiddleware } from './common/sanitization.middleware';
import { RedisService } from './redis/redis.service';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, {
    logger: ['log', 'error', 'warn', 'debug', 'verbose'],
  });

  const config = app.get(ConfigService);
  const redis = app.get(RedisService);

  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'blob:'],
        connectSrc: ["'self'"],
        fontSrc: ["'self'"],
        objectSrc: ["'none'"],
        mediaSrc: ["'self'"],
        frameSrc: ["'none'"],
      },
    },
    crossOriginEmbedderPolicy: true,
    crossOriginOpenerPolicy: true,
    crossOriginResourcePolicy: { policy: 'same-site' },
    dnsPrefetchControl: true,
    frameguard: { action: 'deny' },
    hidePoweredBy: true,
    hsts: { maxAge: 31536000, includeSubDomains: true },
    ieNoOpen: true,
    noSniff: true,
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
    xssFilter: true,
  }));

  app.enableCors({
    origin: (config.get('CORS_ORIGINS') as string ?? '*').split(','),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    maxAge: 86400,
  });

  app.use((req, res, next) => {
    new RateLimitMiddleware(redis).use(req, res, next);
  });

  app.use((req, res, next) => {
    new SanitizationMiddleware().use(req, res, next);
  });

  app.setGlobalPrefix('api');

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
      forbidNonWhitelisted: true,
      forbidUnknownValues: true,
    }),
  );

  const jwtService = app.get(JwtService);
  app.useWebSocketAdapter(new RedisIoAdapter(app, config, jwtService));

  const swaggerConfig = new DocumentBuilder()
    .setTitle('GB Messenger API')
    .setDescription('Black & neon (#CCFF00) messenger backend')
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);

  const port = parseInt(config.get('PORT') as string ?? '3000', 10);
  await app.listen(port);

  Logger.log(`API ready on http://localhost:${port}/api`, 'Bootstrap');
  Logger.log(`Swagger on http://localhost:${port}/api/docs`, 'Bootstrap');
}

void bootstrap();
