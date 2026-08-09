#!/bin/sh
set -e

# Run database migrations using the DATABASE_URL from environment
cd /app
npx prisma migrate deploy

# Start the application
exec node dist/src/main
