#!/bin/bash

set -e

RELEASE_NAME=$1
NAMESPACE=$2

if [ -z "$RELEASE_NAME" ] || [ -z "$NAMESPACE" ]; then
  echo "Usage: rollback.sh <release_name> <namespace>"
  exit 1
fi

echo "Fetching rollout history..."

helm history $RELEASE_NAME -n $NAMESPACE

# Get previous revision (last successful one)
REVISION=$(helm history $RELEASE_NAME -n $NAMESPACE | awk 'NR==3 {print $1}')

if [ -z "$REVISION" ]; then
  echo "No previous revision found!"
  exit 1
fi

echo "Rolling back to revision $REVISION..."

helm rollback $RELEASE_NAME $REVISION -n $NAMESPACE

echo "Rollback completed successfully"