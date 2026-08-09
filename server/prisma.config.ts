import { defineConfig } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: process.env.DATABASE_URL || `postgresql://gbuser:${process.env.POSTGRES_PASSWORD}@postgres:5432/gb_messenger?schema=public`,
  },
});
