#!/bin/bash
set -e

NAMESPACE="exercise-12"

echo "=== 1. Simulating Production Incident: Breaking Database Connectivity ==="
# We update the database password in the secret to an invalid value.
# This does NOT stop the database pod, but will cause payment-service connections to fail.
echo "Applying broken credentials to database secret..."
kubectl patch secret db-credentials -n "$NAMESPACE" -p '{"data":{"DB_PASSWORD":"d3JvbmdfcGFzc3dvcmQ="}}' # base64 for 'wrong_password'

# Force roll out payment-service so it picks up the new bad secret credentials
echo "Restarting payment-service to apply broken credentials..."
kubectl rollout restart deployment/payment-service -n "$NAMESPACE"
kubectl rollout status deployment/payment-service -n "$NAMESPACE" --timeout=60s

echo "=== 2. Starting Load Generator (k6) ==="
# Scale the load generator deployment to 1 replica to start generating traffic
kubectl scale deployment load-generator -n "$NAMESPACE" --replicas=1

echo "Waiting for load generator pod to start..."
kubectl wait --namespace="$NAMESPACE" \
  --for=condition=ready pod \
  --selector=app=load-generator \
  --timeout=60s

echo ""
echo "=== Traffic Generation Active ==="
echo "The load generator is now hitting the frontend service."
echo "Because the database credentials are invalid, the payment-service will trigger a retry storm."
echo "Watch the node disk usage and node status using:"
echo "  kubectl get nodes"
echo "  kubectl describe node"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE -l app=payment-service --tail=20"
