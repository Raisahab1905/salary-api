#!/bin/bash
set -e

echo "🎯 Starting Salary API Application..."

# Wait for databases if environment variables are set
if [ -n "$SCYLLA_HOST" ] && [ -n "$SCYLLA_PORT" ]; then
    echo "⏳ Waiting for ScyllaDB at $SCYLLA_HOST:$SCYLLA_PORT..."
    /usr/local/bin/wait-for "$SCYLLA_HOST" "$SCYLLA_PORT" 60
fi

if [ -n "$REDIS_HOST" ] && [ -n "$REDIS_PORT" ]; then
    echo "⏳ Waiting for Redis at $REDIS_HOST:$REDIS_PORT..."
    /usr/local/bin/wait-for "$REDIS_HOST" "$REDIS_PORT" 30
fi

echo "✅ All dependencies ready! Starting Spring Boot application..."
exec java -jar /app/app.jar "$@"