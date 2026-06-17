# DevOps Lab: ArgoCD OutOfSync Production Incident (Manual Walkthrough)

Welcome to **Exercise 3: ArgoCD OutOfSync Production Incident** lab! This hands-on lab teaches you how ArgoCD detects and reports configuration drift between a Git repository (your single source of truth) and a live Kubernetes cluster.

In this manual version of the lab, you will perform all the steps yourself using `kubectl` commands. You will configure an in-cluster Git repository, deploy a microservice, trigger configuration drift by manually scaling the deployment, troubleshoot the drift using native Kubernetes commands, and learn how to prevent it.

---

## 🏗️ Lab Architecture

The following diagram illustrates how ArgoCD reconciles the **Live State** of Kubernetes against the **Desired State** defined in Git.

```mermaid
flowchart TD
    subgraph Git Repository [Git Repository (Desired State)]
        A[deployment.yaml <br><b>replicas: 3</b>]
    end

    subgraph Kubernetes Cluster [Kubernetes Cluster (Live State)]
        direction TB
        B[payment-service Deployment]
        C[Pod 1]
        D[Pod 2]
        E[Pod 3]
        F[Pod 4]
        G[Pod 5]
        
        B --> C
        B --> D
        B --> E
        B --> F
        B --> G
    end

    subgraph ArgoCD Controller [ArgoCD Namespace]
        H[ArgoCD Application Controller]
    end

    A -- "Read Desired State (3 Replicas)" --> H
    B -- "Read Live State (5 Replicas)" --> H
    H -- "Detects Mismatch" --> I{Status Mismatch?}
    I -- "Yes" --> J["Status: OutOfSync <br> Health: Healthy"]
    
    style J fill:#f96,stroke:#333,stroke-width:2px
    style A fill:#bbf,stroke:#333,stroke-width:2px
    style B fill:#bfb,stroke:#333,stroke-width:2px
```

### Why is the Application `OutOfSync` yet `Healthy`?
- **Status: OutOfSync:** The configuration in Git (replicas: 3) does not match the live cluster configuration (replicas: 5).
- **Health: Healthy:** All 5 pods are running, passing probes, and serving requests successfully. The application itself is functional, but its deployment configuration is drifted.

---

## 📁 Project Structure

```text
exercise-3-argocd/
├── manifests/
│   ├── deployment.yaml            # Desired state: replicas=3
│   ├── service.yaml               # Exposing service on port 80
│   ├── git-server.yaml            # In-cluster local Git server
│   ├── application.yaml           # ArgoCD Application (AutoSync Disabled)
│   └── application-autosync.yaml  # ArgoCD Application (AutoSync Enabled)
└── README.md                      # Lab Guide (This file)
```

---

## 🛠️ Step 1: Manual Setup and Initialization

Follow these commands in your terminal (Bash, Zsh, or Windows PowerShell) to initialize the environment.

### 1. Detect or Start your Cluster
Ensure you have an active local Kubernetes cluster (Minikube or k3d/k3s) running:
```bash
kubectl cluster-info
```

### 2. Create the Namespaces
Create the namespaces for ArgoCD and default workloads:
```bash
kubectl create namespace argocd
kubectl create namespace default
```

### 3. Install ArgoCD
Apply the official non-HA manifests for ArgoCD v2.10.4:
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.4/manifests/install.yaml
```

Wait for the core ArgoCD deployments to become fully available:
```bash
kubectl wait --namespace argocd \
  --for=condition=available \
  deployment/argocd-repo-server \
  deployment/argocd-server \
  deployment/argocd-applicationset-controller \
  --timeout=180s
```

### 4. Deploy the Local Git Server
Deploy the in-cluster Git Server manifest to host the GitOps repository locally:
```bash
kubectl apply -f manifests/git-server.yaml
```

Wait for the Git Server pod to be ready:
```bash
kubectl wait --namespace default \
  --for=condition=Ready \
  pod -l app=git-server \
  --timeout=90s
```

### 5. Manually Populate the Git Server Repository
Copy the local manifest files into the Git Server container, then initialize and commit them:

#### For Bash, Zsh, or WSL:
```bash
# Store the Git server pod name
GIT_POD=$(kubectl get pod -l app=git-server -n default -o jsonpath='{.items[0].metadata.name}')

# Copy manifests to the pod
kubectl cp manifests/deployment.yaml default/${GIT_POD}:/tmp/deployment.yaml
kubectl cp manifests/service.yaml default/${GIT_POD}:/tmp/service.yaml

# Commit manifests to the Git server's repository
kubectl exec ${GIT_POD} -n default -- sh -c "
  set -e
  mkdir -p /tmp/local-repo
  cd /tmp/local-repo
  git init
  git config user.email 'devops@lab.com'
  git config user.name 'DevOps Lab'
  cp /tmp/deployment.yaml .
  cp /tmp/service.yaml .
  git add deployment.yaml service.yaml
  git commit -m 'Initial GitOps commit: Deploy payment-service with 3 replicas'
  git branch -M main
  git remote add origin /git/repo.git
  git push -u origin main --force
"
```

#### For Windows PowerShell:
```powershell
# Store the Git server pod name
$GIT_POD = (kubectl get pod -l app=git-server -n default -o jsonpath='{.items[0].metadata.name}')

# Copy manifests to the pod
kubectl cp manifests/deployment.yaml default/${$GIT_POD}:/tmp/deployment.yaml
kubectl cp manifests/service.yaml default/${$GIT_POD}:/tmp/service.yaml

# Commit manifests to the Git server's repository
kubectl exec $GIT_POD -n default -- sh -c "
  mkdir -p /tmp/local-repo
  cd /tmp/local-repo
  git init
  git config user.email 'devops@lab.com'
  git config user.name 'DevOps Lab'
  cp /tmp/deployment.yaml .
  cp /tmp/service.yaml .
  git add deployment.yaml service.yaml
  git commit -m 'Initial GitOps commit: Deploy payment-service with 3 replicas'
  git branch -M main
  git remote add origin /git/repo.git
  git push -u origin main --force
"
```

### 6. Create the ArgoCD Application
Deploy the ArgoCD Application resource that tracks the Git server repo:
```bash
kubectl apply -f manifests/application.yaml
```

Wait for the deployment to spin up and report available replicas:
```bash
kubectl wait --namespace default \
  --for=condition=Available \
  deployment/payment-service \
  --timeout=120s
```

### 7. Retrieve ArgoCD Credentials
Retrieve the default admin login password:

- **For Bash / WSL:**
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode
  ```
- **For Windows PowerShell:**
  ```powershell
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}")))
  ```

Access the dashboard using a port forward:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
- Open `https://localhost:8080` (bypass certificate warnings).
- **Username:** `admin`
- **Password:** (use the retrieved password value)

---

## 🚨 Step 2: Simulate Configuration Drift (The Incident)

To simulate an incident where an operator bypasses GitOps rules and modifies the cluster live, scale the deployment to **5 replicas** using `kubectl`:

```bash
kubectl scale deployment payment-service --replicas=5 -n default
```

### 1. Check the Live State
Check the deployment scale status:
```bash
kubectl get deployment payment-service -n default
```
Observe that the cluster now has **5 desired replicas** and **5 running pods**.

### 2. Force ArgoCD Application Refresh
To force ArgoCD to immediately reconcile the state change instead of waiting for its standard 3-minute poll interval, annotate the application:
```bash
kubectl annotate application payment-service-app -n argocd argoproj.io/refresh=normal --overwrite
```

### 3. Confirm ArgoCD Status Mismatch
Verify the application sync and health status:
```bash
kubectl get application payment-service-app -n argocd -o jsonpath='{.status.sync.status}'
# Expected Output: OutOfSync

kubectl get application payment-service-app -n argocd -o jsonpath='{.status.health.status}'
# Expected Output: Healthy
```

In the ArgoCD console, you will see a yellow `OutOfSync` card indicating the deployment state diverges by 2 replicas.

---

## 🔍 Step 3: Troubleshooting and Investigation

### A. What Changed?
Find the differences between the source-of-truth file and the live cluster state:
```bash
kubectl diff -f manifests/deployment.yaml -n default
```
*Expected output delta:*
```diff
@@ -9,3 +9,3 @@
 spec:
-  replicas: 3
+  replicas: 5
```

---

### B. Who Changed It?
Since standard Kubernetes doesn't record the actor on the resource history, execute these commands to gather clues:

1. **Rollout History:**
   ```bash
   kubectl rollout history deployment/payment-service -n default
   ```
   *Note:* Shows revisions but does not track the specific CLI user identity.

2. **Kubernetes Events:**
   ```bash
   kubectl get events --sort-by=.metadata.creationTimestamp -n default | grep -E "payment-service|ScalingReplicaSet"
   ```
   *Expected Event Output:*
   ```text
   ScalingReplicaSet   deployment/payment-service   Scaled up replica set payment-service-xxxx to 5 from 3
   ```

3. **Describe Deployment:**
   ```bash
   kubectl describe deployment payment-service -n default
   ```

4. **Resource Annotations:**
   ```bash
   kubectl get deployment payment-service -n default -o jsonpath='{.metadata.annotations}'
   ```

#### Real-World Production Auditing
To find the exact operator in a real cluster, you must check the **Kubernetes API Server Audit Logs** or cloud logging (AWS CloudTrail, GCP Cloud Logging, Azure Monitor).

**Example query in Google Cloud Logging:**
```sql
resource.type="k8s_cluster"
protoPayload.methodName="io.k8s.apps.v1.apps.deployments.rollback" OR "io.k8s.apps.v1.apps.deployments.patch"
protoPayload.resourceName="namespaces/default/deployments/payment-service"
```
This logs query returns:
- `protoPayload.authenticationInfo.principalEmail`: `operator-username@company.com`
- `protoPayload.request.spec.replicas`: `5`
- `protoPayload.userAgent`: `kubectl/v1.29.1`

---

## 🛡️ Step 4: Prevention and Resolution

### 1. Enable ArgoCD AutoSync and SelfHeal
Activate AutoSync and SelfHeal so ArgoCD automatically overrides manual changes to restore the desired state from Git:
```bash
kubectl apply -f manifests/application-autosync.yaml
```

If you try to manually scale to 5 again:
```bash
kubectl scale deployment payment-service --replicas=5
```
Wait a few seconds and run:
```bash
kubectl get deployment payment-service
```
You will observe that ArgoCD instantly detected the deviation and scaled it back to **3 replicas** to match Git.

### 2. Lock Down RBAC Permissions
Restrict manual `update` and `patch` verbs on deployments using Kubernetes RBAC:
```yaml
# Role snippet denying direct deployment updates
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: deployment-reader
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"] # Read-only
```

### 3. Restrict changes using Admission Controllers (Kyverno / OPA)
Deploy Kyverno policies to reject any non-ArgoCD-initiated write operations on critical namespace deployments.

---

## 📝 Root Cause Analysis (RCA) Report Template

Use this format when writing incident reports:

| Section | Detail |
|---|---|
| **Incident Title** | Payment Service OutOfSync Drift in Production Cluster |
| **Severity** | P2 (Medium - Service is healthy but configuration is drifted) |
| **Date & Time** | 2026-06-17 09:32 UTC |
| **Root Cause** | Operator bypassed the GitOps workflow (PR process) and directly executed `kubectl scale` on the live cluster to mitigate load, creating configuration drift. |
| **Detection** | ArgoCD Application dashboard flagged the deployment as `OutOfSync` (yellow status). |
| **Resolution** | Re-applied the ArgoCD configuration or activated `SelfHeal` to restore the desired state (3 replicas). |
| **Preventative Actions** | 1. Enable ArgoCD `SelfHeal` in production.<br>2. Restrict kubectl write access using IAM/RBAC. |

---

## 🧹 Clean Up

To remove all resource manifests created in this lab, run:

```bash
# Delete ArgoCD Application
kubectl delete -f manifests/application.yaml --ignore-not-found=true
kubectl delete -f manifests/application-autosync.yaml --ignore-not-found=true

# Delete workloads
kubectl delete -f manifests/git-server.yaml --ignore-not-found=true
kubectl delete deployment payment-service -n default --ignore-not-found=true
kubectl delete service payment-service -n default --ignore-not-found=true

# Delete ArgoCD namespace
kubectl delete namespace argocd --ignore-not-found=true
```
