# Exercise 12 – Node NotReady Production Incident Lab

This repository contains a complete, self-contained Kubernetes lab environment to simulate a production incident where a worker node transitions to the `NotReady` state due to `DiskPressure` triggered by an application-level **retry storm**.

---

## Lab Architecture

```
  Internet User (k6)
         │
         ▼
  [Frontend Service] (FastAPI)
         │
         ▼
  [Order Service] (FastAPI)
         │
         ▼
  [Payment Service] (FastAPI)  ──(retries)──► [PostgreSQL] (Invalid Credentials)
```

### Components
1. **Frontend Service**: Exposes a public endpoint `/order`.
2. **Order Service**: Coordinates order creation logic and calls the Payment Service.
3. **Payment Service**: Validates and records payments in a PostgreSQL database. Implements custom retry loops with verbose logging when DB connection fails.
4. **PostgreSQL**: Standard relational DB.
5. **Load Generator**: Grafana k6 running inside the cluster.

---

## Prerequisites
- [Docker](https://www.docker.com/)
- [k3d](https://k3d.io/) (K3s in Docker)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- Bash shell (WSL, Git Bash, or Linux/macOS)

---

## Directory Structure

```
exercise-12-node-notready/
├── app/
│   ├── frontend/           # Frontend microservice
│   ├── payment-service/    # Payment microservice (Retry loop & JSON logging)
│   ├── order-service/      # Order microservice
│   └── postgres/           # DB Dockerfile/configuration (if any)
├── k8s/
│   ├── namespace.yaml      # Lab namespace
│   ├── configmap.yaml      # Environment configs
│   ├── secret.yaml         # Database credentials
│   ├── postgres.yaml       # PostgreSQL deployment & service
│   ├── payment.yaml        # Payment deployment & service
│   ├── order.yaml          # Order deployment & service
│   └── frontend.yaml       # Frontend deployment & service
├── load-generator/
│   ├── k6.js               # Load testing script
│   └── load-generator.yaml # k6 deployment manifest
├── scripts/
│   ├── setup.sh            # Build images, start cluster, configure tmpfs, deploy resources
│   ├── generate-traffic.sh # Induce database failure and start traffic generator
│   ├── verify.sh           # Monitor nodes, disk usage, pod statuses, and events
│   ├── recover.sh          # Fix credentials, scale down traffic, truncate logs
│   └── cleanup.sh          # Delete the cluster
├── docs/
│   ├── RCA.md              # Root Cause Analysis
│   └── Troubleshooting.md  # Detailed CLI step-by-step diagnostic guide
└── README.md
```

---

## Step-by-Step Lab Execution

### Step 1: Initialize the Lab Environment
Run the setup script. This script builds the application Docker images, spins up a new k3d cluster (`ex12`), mounts an **80MB tmpfs volume** at `/var/log` inside the agent node container, imports the local images, and applies all manifests.

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

Ensure everything is running normally:
```bash
kubectl get nodes
kubectl get pods -n exercise-12
```
All pods should be in the `Running` state, and the node should be `Ready`.

### Step 2: Trigger the Production Incident
Run the traffic generation script. This script:
1. Replaces the database credentials secret with an **invalid** password (without stopping the database pod).
2. Performs a rollout restart of the `payment-service` to apply the broken configurations.
3. Scales the load generator (k6) to `1` replica to begin sending constant transaction requests.

```bash
./scripts/generate-traffic.sh
```

### Step 3: Observe and Verify the Failure
Use the verification script to monitor the progress of the incident. As k6 sends requests:
- The `payment-service` fails to connect to the database.
- It attempts to retry the connection 10 times per request with a 50ms delay, writing a large structured JSON error message (containing python stack traces and environment data) for each failure.
- The logs fill up the node's `/var/log` container log space rapidly.

Run the verification script:
```bash
./scripts/verify.sh
```

**What you will see:**
1. The node disk space of `/var/log` will hit `100%`.
2. Kubelet events will log a `DiskPressure` warning.
3. The worker node status will transition from `Ready` to `NotReady`.
4. Pods may transition to `Evicted` status.

### Step 4: Troubleshooting and Incident Analysis
Follow [Troubleshooting.md](docs/Troubleshooting.md) for full commands to inspect the logs, find large files, and diagnose the state of the node.
Review [RCA.md](docs/RCA.md) for a complete breakdown of why this occurred.

### Step 5: Recover the Node
Run the recovery script to resolve the incident:
```bash
./scripts/recover.sh
```
This script:
1. Scales the load generator down to `0`.
2. Restores the correct database credentials.
3. **Truncates** all `.log` files in `/var/log/pods` to 0 bytes, immediately releasing node disk space.
4. Restarts the `payment-service` deployment to connect successfully.

Confirm that the node has returned to `Ready` status:
```bash
kubectl get nodes
```

---

## Teardown
To delete the k3d cluster and clean up all local Docker configurations:
```bash
./scripts/cleanup.sh
```
