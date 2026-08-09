#!/bin/sh
set -e

# Run database migrations
cd /app
npx prisma migrate deploy

# Start the application
exec node dist/src/main
