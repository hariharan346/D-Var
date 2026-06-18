# PowerShell Setup Script for Exercise 12
$ErrorActionPreference = "Stop"

$CLUSTER_NAME = "ex12"
$NAMESPACE = "exercise-12"

Write-Host "=== 1. Building Docker Images ===" -ForegroundColor Cyan
docker build -t frontend:latest ./app/frontend
docker build -t order-service:latest ./app/order-service
docker build -t payment-service:latest ./app/payment-service

Write-Host "=== 2. Creating k3d Cluster ===" -ForegroundColor Cyan
# Check if cluster exists
$clusters = k3d cluster list
$clusterExists = $false
foreach ($c in $clusters) {
    if ($c -match $CLUSTER_NAME) {
        $clusterExists = $true
        break
    }
}

if ($clusterExists) {
    Write-Host "Deleting existing cluster $CLUSTER_NAME..." -ForegroundColor Yellow
    k3d cluster delete "$CLUSTER_NAME"
}

# Create cluster
k3d cluster create "$CLUSTER_NAME" --agents 1 --servers 1 --k3s-arg "--disable=traefik@server:*"

Write-Host "=== 3. Importing Images into k3d ===" -ForegroundColor Cyan
k3d image import frontend:latest order-service:latest payment-service:latest -c "$CLUSTER_NAME"

Write-Host "=== 4. Setting up small tmpfs for logs on the agent node ===" -ForegroundColor Cyan
$AGENT_CONTAINER = "k3d-${CLUSTER_NAME}-agent-0"

Write-Host "Mounting 80MB tmpfs for container logs on $AGENT_CONTAINER..." -ForegroundColor Yellow
docker exec "$AGENT_CONTAINER" mount -t tmpfs -o size=80M tmpfs /var/log
docker exec "$AGENT_CONTAINER" mkdir -p /var/log/pods

Write-Host "=== 5. Deploying Kubernetes Manifests ===" -ForegroundColor Cyan
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/payment.yaml
kubectl apply -f k8s/order.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f load-generator/load-generator.yaml

Write-Host "=== 6. Waiting for pods to be ready ===" -ForegroundColor Cyan
kubectl wait --namespace="$NAMESPACE" --for=condition=ready pod --selector=app=postgres --timeout=90s
kubectl wait --namespace="$NAMESPACE" --for=condition=ready pod --selector=app=payment-service --timeout=90s
kubectl wait --namespace="$NAMESPACE" --for=condition=ready pod --selector=app=order-service --timeout=90s
kubectl wait --namespace="$NAMESPACE" --for=condition=ready pod --selector=app=frontend --timeout=90s

Write-Host "=== Setup Completed Successfully ===" -ForegroundColor Green
Write-Host "You can check node status using: kubectl get nodes"
Write-Host "All pods are running under normal state with healthy Postgres connectivity."
