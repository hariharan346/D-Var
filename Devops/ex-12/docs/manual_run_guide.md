# Manual Lab Execution Guide

This document describes how to manually execute the Node NotReady production incident lab step-by-step. It provides the exact CLI commands to configure the environment, trigger the failure, inspect the node conditions, and resolve the incident.

---

## 1. Setup the Environment

First, build the Docker images for all three services:

```bash
# Build Frontend Image
docker build -t frontend:latest ./app/frontend

# Build Order Service Image
docker build -t order-service:latest ./app/order-service

# Build Payment Service Image
docker build -t payment-service:latest ./app/payment-service
```

Create a k3d cluster with 1 agent node:

```bash
k3d cluster create ex12 --agents 1 --servers 1 --k3s-arg "--disable=traefik@server:*"
```

Import your locally built images into the k3d cluster:

```bash
k3d image import frontend:latest order-service:latest payment-service:latest -c ex12
```

Configure a small log limit (80MB tmpfs) on the agent node container so the logs can fill the space quickly:

```bash
# Mount tmpfs to /var/log on the agent node container
docker exec k3d-ex12-agent-0 mount -t tmpfs -o size=80M tmpfs /var/log

# Re-create the pod log directory structure inside the new mount
docker exec k3d-ex12-agent-0 mkdir -p /var/log/pods
```

Apply all the Kubernetes manifests to start the services:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/payment.yaml
kubectl apply -f k8s/order.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f load-generator/load-generator.yaml
```

Wait until all pods are running and ready:

```bash
kubectl get pods -n exercise-12 -w
```

---

## 2. Trigger the Failure Manually

To simulate database connectivity failure, patch the secret with invalid database credentials:

```bash
# Patch the password to "wrong_password" (base64 encoded as d3JvbmdfcGFzc3dvcmQ=)
kubectl patch secret db-credentials -n exercise-12 -p '{"data":{"DB_PASSWORD":"d3JvbmdfcGFzc3dvcmQ="}}'
```

Restart the Payment Service so it picks up the bad credential secret:

```bash
kubectl rollout restart deployment/payment-service -n exercise-12
```

Scale the load generator to start routing requests through the services:

```bash
kubectl scale deployment load-generator -n exercise-12 --replicas=1
```

---

## 3. Diagnose the Incident

As requests are processed, the `payment-service` will begin its rapid database connection retry loop and write verbose error traces to stdout/stderr.

### Check Node Disk Space
Monitor the `/var/log` volume inside the agent node. You will see it fill up to 100%:

```bash
docker exec k3d-ex12-agent-0 df -h /var/log
```

You can view the exact size of the container log files:

```bash
docker exec k3d-ex12-agent-0 du -sh /var/log/pods
```

### Inspect Node Conditions
Look for the `DiskPressure` condition on the node:

```bash
kubectl get nodes

# You will see the agent node transition to NotReady:
# NAME                STATUS     ROLES                  AGE   VERSION
# k3d-ex12-agent-0    NotReady   <none>                 10m   v1.27.4+k3s1
```

Check the detailed node conditions:

```bash
kubectl describe node k3d-ex12-agent-0 | grep -E "DiskPressure|Ready"
```

### Check Kubelet Events
Look for DiskPressure and eviction events:

```bash
kubectl get events -n exercise-12 --sort-by='.metadata.creationTimestamp'
```

---

## 4. Recover the Node Manually

To return the cluster to a healthy state, execute the following recovery steps:

### Step A: Stop Traffic Generation
Scale down the load generator to stop the retry storm:

```bash
kubectl scale deployment load-generator -n exercise-12 --replicas=0
```

### Step B: Fix Database Credentials
Restore the correct password in the Secret (`postgres_password` base64 encoded as `cG9zdGdyZXNfcGFzc3dvcmQ=`):

```bash
kubectl patch secret db-credentials -n exercise-12 -p '{"data":{"DB_PASSWORD":"cG9zdGdyZXNfcGFzc3dvcmQ="}}'
```

### Step C: Clear the Logs Safely
Do not delete the `.log` files directly since active processes have file handles open. Instead, **truncate** them to `0` bytes:

```bash
docker exec k3d-ex12-agent-0 sh -c 'find /var/log/pods -name "*.log" -exec truncate -s 0 {} +'
```

Confirm that the space is cleared:

```bash
docker exec k3d-ex12-agent-0 df -h /var/log
```

### Step D: Restart the Service
Restart the Payment Service so it successfully authenticates with the database:

```bash
kubectl rollout restart deployment/payment-service -n exercise-12
```

Wait 10-15 seconds and check the node status again. The node status will return to `Ready`:

```bash
kubectl get nodes
```
