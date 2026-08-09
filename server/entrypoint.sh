#!/bin/sh
set -e

# Create .env file with DATABASE_URL for Prisma
cd /app
cat > .env << ENVFILE
DATABASE_URL=${DATABASE_URL}
REDIS_URL=${REDIS_URL}
JWT_ACCESS_SECRET=${JWT_ACCESS_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
ENCRYPTION_KEY=${ENCRYPTION_KEY}
ENVFILE

# Run database migrations
npx prisma migrate deploy

# Start the application
exec node dist/src/main
