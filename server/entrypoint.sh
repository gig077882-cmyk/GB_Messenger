#!/bin/sh
set -e

# Set DATABASE_URL from container environment
cd /app
export DATABASE_URL="${DATABASE_URL:-postgresql://gbuser@postgres:5432/gb_messenger?schema=public}"

# Run database migrations
npx prisma migrate deploy

# Start the application
exec node dist/src/main
