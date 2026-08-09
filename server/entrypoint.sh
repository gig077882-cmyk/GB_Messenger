#!/bin/sh
set -e

# Create .env file for Prisma
cd /app
echo "DATABASE_URL=$DATABASE_URL" > .env

# Run database migrations
npx prisma migrate deploy

# Start the application
exec node dist/src/main
