# DevOps Lab: ArgoCD OutOfSync Production Incident Resolution

This documentation records the details of the **Exercise 3: ArgoCD OutOfSync** production incident, how it was built, and how it was successfully resolved.

---

## The Incident (What is the Task?)
A manual operator intervention bypassed the GitOps pipeline, creating configuration drift between the Git repository and the live cluster.

* **Symptom:**
  * **Sync Status:** `OutOfSync` (Git specifies 3 replicas; live cluster has 5).
  * **Health Status:** `Healthy` (All 5 pods are running successfully).
* **Verify Sync State:**
  ```bash
  kubectl get application payment-service-app -n argocd -o jsonpath='{.status.sync.status}'
  # Output: OutOfSync
  ```

---

## How We Built the Lab
We set up a local GitOps environment using your public GitHub repository:
1. **GitHub Repository:** Pushed manifests for the payment service workload to `https://github.com/hariharan346/D-Var.git`.
2. **ArgoCD Application:** Deployed ArgoCD and applied [manifests/application.yaml](file:///e:/AIVAR/Devops/exercise-3-argocd/manifests/application.yaml) pointing to your repo subfolder with `exclude` settings for application files.
3. **Simulate Drift:** Bypassed GitOps by manually scaling the live deployment:
   ```bash
   kubectl scale deployment payment-service --replicas=5
   kubectl annotate application payment-service-app -n argocd argoproj.io/refresh=normal --overwrite
   ```

---

## How I Investigated It
We analyzed the incident using these troubleshooting steps:

1. **What Changed (Verify Drift):**
   ```bash
   kubectl diff -f manifests/deployment.yaml
   # Output delta shows replicas drifted from 3 to 5
   ```
2. **Who Changed It:**
   * Running `kubectl rollout history` and `kubectl get events` showed that a scaling action occurred, but local events do not store the operator's IAM identity.
   * **Real-World Auditing:** In production, we query the **Kubernetes API Server Audit Logs** or Cloud Logs (like AWS CloudTrail/GCP Logging) for `PATCH` requests on `deployments/payment-service` to identify the exact user name (e.g. `operator@company.com`) and user-agent.

---

## How I Solved It (The Fix)
Depending on the production requirement, we can resolve the drift in two ways:

### Method A: Revert manual changes to match Git (Restore to 3 Replicas)
Enforce Git as the single source of truth:
* **Via UI:** Click **`SYNC`** -> **`SYNCHRONIZE`** on the ArgoCD dashboard.
* **Via Policy:** Enable Self-Healing by deploying the auto-sync configuration:
  ```bash
  kubectl apply -f manifests/application-autosync.yaml
  ```
  *(ArgoCD will automatically scale the live cluster back to 3 replicas).*

### Method B: Update Git to match the live cluster (Promote to 5 Replicas)
If 5 replicas are required permanently:
1. Change `replicas: 3` to `replicas: 5` in [manifests/deployment.yaml](file:///e:/AIVAR/Devops/exercise-3-argocd/manifests/deployment.yaml).
2. Commit and push the changes:
   ```bash
   git add manifests/deployment.yaml
   git commit -m "Scale payment-service to 5 replicas"
   git push
   ```
3. Refresh ArgoCD. The status will return to **`Synced` (Green)**.
