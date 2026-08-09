#!/bin/sh
set -e

# Export DATABASE_URL for Prisma
cd /app
export DATABASE_URL="postgresql://gbuser:${POSTGRES_PASSWORD}@postgres:5432/gb_messenger?schema=public"

# Run database migrations
npx prisma migrate deploy

# Start the application
exec node dist/src/main
