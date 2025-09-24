#!/bin/bash
host="$1"
port="$2"
timeout=${3:-60}
echo "Waiting for $host:$port..."
for i in $(seq 1 $timeout); do
  # Try multiple connection methods
  if timeout 1 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null || \
     curl -s "http://$host:$port" > /dev/null 2>&1 || \
     nc -z "$host" "$port" 2>/dev/null; then
    echo "$host:$port is available!"
    exit 0
  fi
  sleep 1
done
echo "Timeout waiting for $host:$port"
exit 1
