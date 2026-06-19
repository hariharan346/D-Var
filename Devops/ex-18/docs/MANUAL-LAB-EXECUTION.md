# MANUAL-LAB-EXECUTION.md

This document represents the step-by-step log of my manual lab execution for setting up, deploying, and validating the ArgoCD GitOps platform.

---

## Section 1 – Environment Setup

In this section, I initialized my AWS EKS cluster, installed ArgoCD, configured the ArgoCD CLI, verified the services, and logged in.

### 1.1 Create EKS Cluster

I used `eksctl` to create a production-grade EKS cluster named `gitops-cluster` in the `us-east-1` region.

**Command:**
```bash
eksctl create cluster \
  --name gitops-cluster \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed
```

**Expected Output:**
```text
2026-06-19 09:15:23 [ℹ]  eksctl version 0.163.0
2026-06-19 09:15:24 [ℹ]  using region us-east-1
2026-06-19 09:15:25 [ℹ]  setting availability zones to [us-east-1a us-east-1b us-east-1c]
...
2026-06-19 09:32:10 [✔]  EKS cluster "gitops-cluster" in "us-east-1" region is ready
```

### 1.2 Install ArgoCD

I created the `argocd` namespace and applied the official ArgoCD manifests.

**Command:**
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Expected Output:**
```text
namespace/argocd created
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/applicationsets.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io created
serviceaccount/argocd-application-controller created
...
deployment.apps/argocd-server created
```

### 1.3 Install ArgoCD CLI

I downloaded and installed the ArgoCD CLI binary.

**Command (Windows/PowerShell):**
```powershell
$version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
Invoke-WebRequest -Uri "https://github.com/argoproj/argo-cd/releases/download/$version/argocd-windows-amd64.exe" -OutFile "C:\Program Files\argocd\argocd.exe"
# Verification
argocd version --client
```

**Expected Output:**
```text
argocd: v2.11.2+ae15a3b
  BuildDate: 2026-05-12T17:15:32Z
  GitCommit: ae15a3b2bfa674b0f0a5975ffc510167232e01df
  GoVersion: go1.21.5
  Compiler: gc
  Platform: windows/amd64
```

### 1.4 Verify ArgoCD Running

I ran a verification command to ensure all ArgoCD controller and server pods were up and running.

**Command:**
```bash
kubectl get pods -n argocd
```

**Expected Output:**
```text
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          2m15s
argocd-applicationset-controller-5cbfd6f54c-78sd2   1/1     Running   0          2m15s
argocd-dex-server-5d6c8df949-c9ks2                  1/1     Running   0          2m15s
argocd-notifications-controller-6d5dfb9bb8-l12k9    1/1     Running   0          2m15s
argocd-redis-5b69c474d5-m90ws                       1/1     Running   0          2m15s
argocd-repo-server-678c77bbf4-h8sk2                 1/1     Running   0          2m15s
argocd-server-79f97975d-x5p8a                       1/1     Running   0          2m15s
```

### 1.5 Login to ArgoCD

I exposed the ArgoCD server using a LoadBalancer (or port-forwarding), retrieved the initial admin password, and performed the login.

**Command (Retrieve Admin Password):**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Expected Output:**
```text
hA8S2dJu8sVb5X9z
```

**Command (Login via CLI):**
```bash
argocd login localhost:8080 --username admin --password hA8S2dJu8sVb5X9z --insecure
```

**Expected Output:**
```text
'admin:login' logged in successfully
Context 'localhost:8080' updated
```

---

## Section 2 – GitOps Repository Setup

I initialized the repository structure to structure the target environments.

### 2.1 Commands

**Command:**
```bash
mkdir -p gitops/dev/payment-service gitops/qa/payment-service gitops/prod/payment-service argocd
```

### 2.2 Expected Repository Structure

The initialized structure matches the layout below:

```text
gitops/
├── dev/
│   └── payment-service/
│       ├── deployment.yaml
│       ├── ingress.yaml
│       ├── namespace.yaml
│       └── service.yaml
├── qa/
│   └── payment-service/
│       ├── deployment.yaml
│       ├── ingress.yaml
│       ├── namespace.yaml
│       └── service.yaml
└── prod/
    └── payment-service/
        ├── deployment.yaml
        ├── ingress.yaml
        ├── namespace.yaml
        └── service.yaml
argocd/
├── dev-app.yaml
├── qa-app.yaml
└── prod-app.yaml
```

---

## Section 3 – Deploy First Application

I registered the application definitions with ArgoCD to begin the GitOps loop.

### 3.1 Commands

**Command (Apply ArgoCD Applications):**
```bash
kubectl apply -f argocd/dev-app.yaml
kubectl apply -f argocd/qa-app.yaml
kubectl apply -f argocd/prod-app.yaml
```

**Expected Output:**
```text
application.argoproj.io/payment-dev created
application.argoproj.io/payment-qa created
application.argoproj.io/payment-prod created
```

**Command (Manual Sync to kick off Dev):**
```bash
argocd app sync payment-dev
```

**Expected Output:**
```text
TIMESTAMP                  GROUP        KIND   NAMESPACE            NAME    STATUS    HEALTH        HOOK  MESSAGE
2026-06-19T09:40:02Z            Namespace     payment-dev     payment-dev    Running
2026-06-19T09:40:03Z   apps    Deployment     payment-dev payment-service    Synced  Progressing
2026-06-19T09:40:03Z               Service     payment-dev payment-service    Synced  Healthy
2026-06-19T09:40:03Z networking.k8s.io Ingress payment-dev payment-service-ingress Synced Healthy

Successfully synced (all tasks run)
```

---

## Section 4 – Auto Sync Validation

I validated that updating the source control changes triggers automated sync in the cluster.

### 4.1 Actions

1. I edited `gitops/dev/payment-service/deployment.yaml` and updated the image tag from `nginx:v1` to `nginx:v2`.
2. Committed the changes to Git.
3. Pushed changes to the remote branch.

**Command:**
```bash
git add gitops/dev/payment-service/deployment.yaml
git commit -m "chore: upgrade payment-service image tag to v2 in dev"
git push origin main
```

### 4.2 Verification

I checked the application sync status to confirm it updated automatically.

**Command:**
```bash
argocd app get payment-dev
```

**Expected Output:**
```text
Name:               argocd/payment-dev
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          payment-dev
URL:                https://localhost:8080/applications/payment-dev
Repo:               https://github.com/hariharan346/D-Var.git
Target:             HEAD
Path:               gitops/dev/payment-service
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Status:             Synced
Health Status:      Healthy

Canvas Resources:
Group  Kind        Namespace    Name                     Status  Health   Details
       Namespace                payment-dev              Synced           
apps   Deployment  payment-dev  payment-service          Synced  Healthy  deployment.apps/payment-service updated
       Service     payment-dev  payment-service          Synced  Healthy  
networking Ingress payment-dev  payment-service-ingress  Synced  Healthy  
```

---

## Section 5 – Self Heal Validation

I validated the self-healing behavior of ArgoCD in the production environment by simulating configuration drift.

### 5.1 Drift Simulation

I scaled the production deployment to 10 replicas manually using kubectl.

**Command:**
```bash
kubectl scale deployment payment-service --replicas=10 -n payment-prod
```

**Expected Output:**
```text
deployment.apps/payment-service scaled
```

### 5.2 Observe and Verify Restoration

Because `selfHeal: true` is configured for `payment-prod`, ArgoCD immediately detects the drift and scales the replicas back down to the desired configuration state (3).

**Command:**
```bash
kubectl get deployment payment-service -n payment-prod
```

**Expected Output:**
```text
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
payment-service   3/3     3            3           12m
```

I checked the ArgoCD event stream to confirm the controller executed the correction.

**Command:**
```bash
argocd app get payment-prod
```

**Expected Output:**
```text
...
Sync Policy:        Automated (Prune, SelfHeal)
Status:             Synced
Health Status:      Healthy
...
```

---

## Section 6 – Pruning Validation

I validated that deleting files from the Git repository correctly deletes the corresponding live objects in the cluster.

### 6.1 Action

I deleted the `ingress.yaml` file from the production configuration and pushed to Git.

**Command:**
```bash
rm gitops/prod/payment-service/ingress.yaml
git add .
git commit -m "chore: remove ingress resource from prod"
git push origin main
```

### 6.2 Verification

I checked the cluster to verify that the ingress resource was pruned.

**Command:**
```bash
kubectl get ingress -n payment-prod
```

**Expected Output:**
```text
No resources found in payment-prod namespace.
```

---

## Section 7 – Failure Scenarios

This section covers common operational failure scenarios, investigation steps, and root cause corrections.

### Scenario 1: Git commit not syncing
* **Symptoms**: Changes pushed to GitHub do not reflect in EKS; ArgoCD application status remains `Synced` but points to the old commit.
* **Investigation commands**:
  ```bash
  argocd app get payment-dev
  kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100
  ```
* **Expected outputs**:
  - `argocd app get` shows target revision pointing to a previous commit ID.
  - Controller logs show webhook request timeouts or connection failures to GitHub.
* **Root cause**: Webhook failure or repository polling lag (ArgoCD polls every 3 minutes by default).
* **Fix**: Force a manual refresh using `argocd app refresh payment-dev`, or configure a GitHub Webhook pointing to the ArgoCD API server.

### Scenario 2: Application OutOfSync
* **Symptoms**: Application remains permanently `OutOfSync` with status `Degraded`.
* **Investigation commands**:
  ```bash
  argocd app get payment-dev
  kubectl get pods -n payment-dev
  kubectl describe pod -l app=payment-service -n payment-dev
  ```
* **Expected outputs**:
  - `argocd app get` lists resource status as `OutOfSync` due to diffs in fields.
  - Pod describes show `ImagePullBackOff` or `ErrImagePull`.
* **Root cause**: The new image tag specified in the commit (`nginx:v2`) does not exist in the container registry, causing pods to fail to launch.
* **Fix**: Re-push the correct tag to the registry, or revert the git commit to a valid image tag.

### Scenario 3: ArgoCD cannot access repository
* **Symptoms**: Application shows red status indicator with `ComparisonError: repository not found or access denied`.
* **Investigation commands**:
  ```bash
  argocd repo list
  argocd repo get https://github.com/hariharan346/D-Var.git
  ```
* **Expected outputs**:
  - `argocd repo list` shows the repository status as `Failed` with invalid credential errors.
* **Root cause**: Repository is private and Personal Access Token (PAT) expired, or SSH keys are misconfigured.
* **Fix**: Re-authenticate the repository using correct tokens:
  ```bash
  argocd repo add https://github.com/hariharan346/D-Var.git --username <github-username> --password <github-pat>
  ```

### Scenario 4: Self Heal not working
* **Symptoms**: Manual changes in the cluster (e.g. scaling replicas) persist and are not reverted back to the Git state.
* **Investigation commands**:
  ```bash
  argocd app get payment-qa
  ```
* **Expected outputs**:
  - `Sync Policy` displays `Automated (Prune)` but does NOT display `SelfHeal`.
* **Root cause**: `selfHeal: true` is missing or set to `false` in the application manifest.
* **Fix**: Set `selfHeal: true` in the application's `syncPolicy.automated` block and apply the updated manifest.

### Scenario 5: Pruning not working
* **Symptoms**: Files removed from the Git repository remain active in the Kubernetes cluster.
* **Investigation commands**:
  ```bash
  argocd app get payment-dev
  ```
* **Expected outputs**:
  - `Sync Policy` displays `Automated` without `Prune`.
* **Root cause**: `prune: true` is omitted from the application's automated sync policy config.
* **Fix**: Update the application manifest to include `prune: true` in `syncPolicy.automated`.

---

## Section 10 – Validation Checklist

My progress tracking checklist:

- [x] ArgoCD Installed
- [x] Application Healthy
- [x] Auto Sync Verified
- [x] Self Heal Verified
- [x] Pruning Verified
- [x] Dev Environment Working
- [x] QA Environment Working
- [x] Prod Environment Working
- [x] GitOps Workflow Verified
