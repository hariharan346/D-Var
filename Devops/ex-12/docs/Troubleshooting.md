# Troubleshooting Guide
**Resolving Kubelet DiskPressure & Node NotReady Incident**

This guide provides step-by-step procedures for debugging and resolving a worker node `NotReady` state caused by `DiskPressure` from application logging.

---

## 1. Diagnose Node Status & Conditions

First, check if the node is indeed `NotReady` and identify the condition causing it.

```bash
# Check node status
kubectl get nodes

# Output:
# NAME                STATUS     ROLES                  AGE   VERSION
# k3d-ex12-server-0   Ready      control-plane,master   10m   v1.27.4+k3s1
# k3d-ex12-agent-0    NotReady   <none>                 10m   v1.27.4+k3s1
```

Describe the node to check for `DiskPressure`:

```bash
kubectl describe node k3d-ex12-agent-0 | grep -A 5 "Conditions:"
```

Look for:
* `DiskPressure: True`
* `Ready: False`

Verify kubelet events:

```bash
kubectl get events --all-namespaces --sort-by='.metadata.creationTimestamp' | grep -i "DiskPressure"
```

---

## 2. Inspect Disk Usage on the Host/Node

Log into the node container to check disk space:

```bash
# For k3d, access the agent container
docker exec -it k3d-ex12-agent-0 df -h /var/log
```

If `/var/log` (or root `/`) is at 100% capacity, investigate where the logs are located.

```bash
# Locate largest log directories
docker exec -it k3d-ex12-agent-0 du -sh /var/log/pods/*
```

Inside the pods directory, find the logs for the payment-service:
```bash
docker exec -it k3d-ex12-agent-0 du -sh /var/log/pods/exercise-12_payment-service-*/*
```

---

## 3. Verify Application Behavior

Check logs of the offending pod (if it's still running and hasn't been evicted):

```bash
kubectl logs -n exercise-12 -l app=payment-service --tail=50
```

Look for:
* Rapid connection retries (`db_connection_attempt`)
* High-frequency error tracebacks (`db_connection_failed`)
* Exhausted retries (`db_connection_retries_exhausted`)

---

## 4. Mitigation and Recovery

### Step A: Stop the Traffic Storm
Scale the traffic generator to `0` to prevent new logs from being generated:

```bash
kubectl scale deployment load-generator -n exercise-12 --replicas=0
```

### Step B: Safely Rotate/Truncate Logs
To free up disk space immediately, **do NOT delete the files**, as the container runtime still holds the file handles open. Instead, **truncate** the files to `0` bytes:

```bash
docker exec -it k3d-ex12-agent-0 sh -c 'find /var/log/pods -name "*.log" -exec truncate -s 0 {} +'
```

Verify that the disk space has been reclaimed:

```bash
docker exec -it k3d-ex12-agent-0 df -h /var/log
```

### Step C: Fix Root Cause
Apply the correct database credentials back to the secret:

```bash
kubectl patch secret db-credentials -n exercise-12 -p '{"data":{"DB_PASSWORD":"cG9zdGdyZXNfcGFzc3dvcmQ="}}'
```

Force-restart the `payment-service` deployment to pick up the healthy configurations:

```bash
kubectl rollout restart deployment/payment-service -n exercise-12
```

---

## 5. Verify Resolution
After 10-15 seconds, check that the node condition has recovered:

```bash
kubectl get nodes
kubectl get pods -n exercise-12
```
The node status should transition back to `Ready`.
