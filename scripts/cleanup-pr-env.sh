#!/bin/bash

set -e

PR_ID=$1

if [ -z "$PR_ID" ]; then
  echo "Usage: cleanup-pr-env.sh <pr_id>"
  exit 1
fi

NAMESPACE="pr-$PR_ID"

echo "Deleting namespace: $NAMESPACE"

kubectl delete namespace $NAMESPACE --ignore-not-found=true

echo "Cleanup completed"
