#!/bin/sh
set -e

# Run database migrations
cd /app
export DATABASE_URL="postgresql://gbuser:${POSTGRES_PASSWORD}@postgres:5432/gb_messenger?schema=public"
npx prisma migrate deploy

# Start the application
exec node dist/src/main
