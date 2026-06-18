#!/bin/bash

CLUSTER_NAME="ex12"
NAMESPACE="exercise-12"
AGENT_CONTAINER="k3d-${CLUSTER_NAME}-agent-0"

echo "=== 1. Node Status and Conditions ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,REASON:.status.conditions[-1].reason,MESSAGE:.status.conditions[-1].message

echo ""
echo "=== Detailed Node Conditions ==="
kubectl describe node | grep -E "DiskPressure|OutOfDisk|PIDPressure|MemoryPressure|Ready"

echo ""
echo "=== 2. Disk Usage inside Agent Node Container ==="
if docker ps | grep -q "$AGENT_CONTAINER"; then
  echo "Disk usage of /var/log on agent node:"
  docker exec "$AGENT_CONTAINER" df -h /var/log
  echo ""
  echo "Size of container log files:"
  docker exec "$AGENT_CONTAINER" du -sh /var/log/pods || true
else
  echo "Agent node container $AGENT_CONTAINER not found or not running."
fi

echo ""
echo "=== 3. Pod Status in Namespace $NAMESPACE ==="
kubectl get pods -n "$NAMESPACE"

echo ""
echo "=== 4. Recent Eviction Events ==="
kubectl get events -n "$NAMESPACE" --sort-by='.metadata.creationTimestamp' | grep -i -E "evict|disk|pressure|failed" || echo "No eviction/disk pressure events found yet."

echo ""
echo "=== 5. Payment Service Log Growth ==="
PAYMENT_POD=$(kubectl get pods -n "$NAMESPACE" -l app=payment-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$PAYMENT_POD" ]; then
  echo "Tail of payment-service logs:"
  kubectl logs -n "$NAMESPACE" "$PAYMENT_POD" --tail=10
else
  echo "No payment-service pod found."
fi
