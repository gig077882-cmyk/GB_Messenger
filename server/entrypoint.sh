#!/bin/sh
set -e

# Run database migrations
cd /app
export DATABASE_URL="postgresql://gbuser:d662e5e46b4a16a31808db24fc7d7b74@postgres:5432/gb_messenger?schema=public"
npx prisma migrate deploy

# Start the application
exec node dist/src/main
