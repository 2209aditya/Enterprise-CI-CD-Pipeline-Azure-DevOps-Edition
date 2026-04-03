#!/bin/bash

set -e

URL=$1
RETRIES=10
SLEEP=5

if [ -z "$URL" ]; then
  echo "Usage: smoke-test.sh <url>"
  exit 1
fi

echo "Running smoke test on $URL"

for i in $(seq 1 $RETRIES); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

  if [ "$STATUS" -eq 200 ]; then
    echo "✅ Application is healthy (HTTP 200)"
    exit 0
  fi

  echo "Attempt $i failed (status: $STATUS), retrying in $SLEEP sec..."
  sleep $SLEEP
done

echo "❌ Smoke test failed after $RETRIES attempts"
exit 1
