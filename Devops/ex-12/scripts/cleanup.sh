#!/bin/bash
set -e

CLUSTER_NAME="ex12"

echo "=== Tearing Down Lab Environment ==="
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
  echo "Deleting k3d cluster $CLUSTER_NAME..."
  k3d cluster delete "$CLUSTER_NAME"
else
  echo "Cluster $CLUSTER_NAME does not exist."
fi

echo "=== Cleanup Complete ==="
