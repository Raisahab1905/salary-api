#!/bin/sh
# wait-for.sh

set -e

host="$1"
port="$2"
timeout="${3:-60}"

echo "Waiting for $host:$port to be available..."

for i in $(seq 1 $timeout); do
    if nc -z "$host" "$port"; then
        echo "✅ $host:$port is available!"
        exit 0
    fi
    echo "⏳ Attempt $i/$timeout: $host:$port not ready yet..."
    sleep 1
done

echo "❌ Timeout: $host:$port not available after $timeout seconds"
exit 1