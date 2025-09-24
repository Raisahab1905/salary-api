#!/bin/bash
set -e

# Wait for dependencies if environment variables are set
if [ -n "$SCYLLA_HOST" ] && [ -n "$SCYLLA_PORT" ]; then
    echo "Waiting for Scylla at $SCYLLA_HOST:$SCYLLA_PORT..."
    wait-for "$SCYLLA_HOST:$SCYLLA_PORT" --timeout=60
fi

if [ -n "$REDIS_HOST" ] && [ -n "$REDIS_PORT" ]; then
    echo "Waiting for Redis at $REDIS_HOST:$REDIS_PORT..."
    wait-for "$REDIS_HOST:$REDIS_PORT" --timeout=60
fi

echo "All dependencies ready. Starting application..."
exec java -jar app.jar "$@"
