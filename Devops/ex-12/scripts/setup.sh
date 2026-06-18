#!/bin/bash
set -e

CLUSTER_NAME="ex12"
NAMESPACE="exercise-12"

echo "=== 1. Building Docker Images ==="
docker build -t frontend:latest ./app/frontend
docker build -t order-service:latest ./app/order-service
docker build -t payment-service:latest ./app/payment-service

echo "=== 2. Creating k3d Cluster ==="
# Delete existing cluster if it exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
  echo "Deleting existing cluster $CLUSTER_NAME..."
  k3d cluster delete "$CLUSTER_NAME"
fi

# Create cluster with 1 server and 1 agent (making the agent our target node)
# We disable traefik to save resources
k3d cluster create "$CLUSTER_NAME" \
  --agents 1 \
  --servers 1 \
  --k3s-arg "--disable=traefik@server:*"

echo "=== 3. Importing Images into k3d ==="
k3d image import frontend:latest order-service:latest payment-service:latest -c "$CLUSTER_NAME"

echo "=== 4. Setting up small tmpfs for logs on the agent node ==="
# The agent container runs our application pods. Let's find its container name.
AGENT_CONTAINER="k3d-${CLUSTER_NAME}-agent-0"

echo "Mounting 80MB tmpfs for container logs on $AGENT_CONTAINER..."
# Mount tmpfs to /var/log on the agent node so logs quickly trigger DiskPressure.
docker exec "$AGENT_CONTAINER" mount -t tmpfs -o size=80M tmpfs /var/log
docker exec "$AGENT_CONTAINER" mkdir -p /var/log/pods

echo "=== 5. Deploying Kubernetes Manifests ==="
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/payment.yaml
kubectl apply -f k8s/order.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f load-generator/load-generator.yaml

echo "=== 6. Waiting for pods to be ready ==="
kubectl wait --namespace="$NAMESPACE" \
  --for=condition=ready pod \
  --selector=app=postgres \
  --timeout=90s

kubectl wait --namespace="$NAMESPACE" \
  --for=condition=ready pod \
  --selector=app=payment-service \
  --timeout=90s

kubectl wait --namespace="$NAMESPACE" \
  --for=condition=ready pod \
  --selector=app=order-service \
  --timeout=90s

kubectl wait --namespace="$NAMESPACE" \
  --for=condition=ready pod \
  --selector=app=frontend \
  --timeout=90s

echo "=== Setup Completed Successfully ==="
echo "You can check node status using: kubectl get nodes"
echo "All pods are running under normal state with healthy Postgres connectivity."
