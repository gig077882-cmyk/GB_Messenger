#!/bin/sh
set -e

# Start the application (run migrations manually if needed)
cd /app
exec node dist/src/main
