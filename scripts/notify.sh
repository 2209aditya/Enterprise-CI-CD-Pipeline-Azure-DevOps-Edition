#!/bin/bash

set -e

WEBHOOK_URL=$1
MESSAGE=$2
STATUS=$3

if [ -z "$WEBHOOK_URL" ] || [ -z "$MESSAGE" ]; then
  echo "Usage: notify.sh <webhook_url> <message> <status>"
  exit 1
fi

# Color based on status
if [ "$STATUS" == "SUCCESS" ]; then
  COLOR="#2eb886"
elif [ "$STATUS" == "FAILURE" ]; then
  COLOR="#e01e5a"
else
  COLOR="#daa038"
fi

payload=$(cat <<EOF
{
  "attachments": [
    {
      "color": "$COLOR",
      "title": "CI/CD Notification",
      "text": "$MESSAGE",
      "footer": "Azure DevOps Pipeline",
      "ts": $(date +%s)
    }
  ]
}
EOF
)

curl -X POST -H 'Content-type: application/json' \
  --data "$payload" \
  "$WEBHOOK_URL"

echo "Slack notification sent"