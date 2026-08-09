import { defineConfig } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: process.env.DATABASE_URL || 'postgresql://gbuser:d662e5e46b4a16a31808db24fc7d7b74@postgres:5432/gb_messenger?schema=public',
  },
});
