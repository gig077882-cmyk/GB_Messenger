#!/bin/sh
set -e

# Run database migrations
cd /app
npx prisma db push --accept-data-loss

# Start the application
exec node dist/src/main
