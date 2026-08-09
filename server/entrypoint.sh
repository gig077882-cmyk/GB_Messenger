#!/bin/sh
set -e

# Wait for database to be ready
echo "Waiting for database..."
timeout=60
while ! nc -z postgres 5432 2>/dev/null; do
  timeout=$((timeout - 1))
  if [ $timeout -le 0 ]; then
    echo "Timeout waiting for database"
    exit 1
  fi
  echo "Database not ready, waiting..."
  sleep 2
done

echo "Database is ready!"

# Run database migrations
cd /app
export DATABASE_URL="postgresql://gbuser:${POSTGRES_PASSWORD}@postgres:5432/gb_messenger?schema=public"
npx prisma migrate deploy

# Start the application
exec node dist/src/main
