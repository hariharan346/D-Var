#!/bin/bash
set -e

CLUSTER_NAME="ex12"
NAMESPACE="exercise-12"
AGENT_CONTAINER="k3d-${CLUSTER_NAME}-agent-0"

echo "=== 1. Stopping Retry Storm ==="
echo "Scaling load generator to 0..."
kubectl scale deployment load-generator -n "$NAMESPACE" --replicas=0

echo "=== 2. Fixing Database Credentials ==="
echo "Restoring correct credentials in secret..."
kubectl patch secret db-credentials -n "$NAMESPACE" -p '{"data":{"DB_PASSWORD":"cG9zdGdyZXNfcGFzc3dvcmQ="}}'

echo "=== 3. Cleaning Up Logs to Clear DiskPressure ==="
if docker ps | grep -q "$AGENT_CONTAINER"; then
  echo "Truncating container log files on $AGENT_CONTAINER to free disk space..."
  # Truncate all log files to 0 size to release the space immediately
  docker exec "$AGENT_CONTAINER" sh -c 'find /var/log/pods -name "*.log" -exec truncate -s 0 {} +'
  
  echo "Disk usage after log cleanup:"
  docker exec "$AGENT_CONTAINER" df -h /var/log
else
  echo "Agent node container $AGENT_CONTAINER not found. Skipping log truncation."
fi

echo "=== 4. Rolling Out Payment Service with Correct Credentials ==="
kubectl rollout restart deployment/payment-service -n "$NAMESPACE"
kubectl rollout status deployment/payment-service -n "$NAMESPACE" --timeout=60s

echo "=== 5. Verification ==="
echo "Waiting for DiskPressure condition to clear..."
sleep 10

echo "Current node status:"
kubectl get nodes

echo "Current pods in $NAMESPACE:"
kubectl get pods -n "$NAMESPACE"

echo "=== Recovery Completed Successfully ==="
