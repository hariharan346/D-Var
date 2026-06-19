# Root Cause Analysis (RCA) - Incident Report

**Incident ID**: INC-20260619  
**Severity**: High  
**Date**: 2026-06-19  
**Status**: Resolved  

---

## 1. Incident Summary
On June 19, 2026, the deployment of `payment-service` to the production environment stalled. Although developers committed and pushed code changes to the production branch, the EKS cluster did not reflect the updates, leaving the production deployment out-of-sync with Git.

---

## 2. Timeline
- **09:30 AM**: Developer pushes updated container image reference (`nginx:v2`) to the production directory in the GitOps repository.
- **09:35 AM**: Production release validation alerts fire; the live website does not show the new v2 features.
- **09:40 AM**: On-call engineer inspects EKS cluster and notices the pods are running `nginx:v1`.
- **09:45 AM**: Engineer begins investigation of ArgoCD Application Controller logs.
- **09:50 AM**: Engineer identifies connection timeout errors between ArgoCD and the remote Git repository server.
- **09:55 AM**: Root cause identified (expired Personal Access Token/Credentials for repository pull access).
- **10:05 AM**: Token rotated and updated in ArgoCD secrets.
- **10:10 AM**: App sync automatically triggers; system restores to a fully healthy, synchronized state.

---

## 3. Impact
- **Service Impacted**: `payment-service` (Production)
- **Duration**: 40 minutes
- **Description**: Deployment of the critical v2 feature release was delayed. Active production traffic remained on the v1 release, avoiding direct downtime but delaying delivery of critical bug fixes.

---

## 4. Investigation
1. Checked active pods in EKS:
   ```bash
   kubectl get pods -n payment-prod -o jsonpath='{.items[*].spec.containers[*].image}'
   # Returned: nginx:v1
   ```
2. Checked application sync status in ArgoCD:
   ```bash
   argocd app get payment-prod
   # Returned Connection Status: Failed
   ```
3. Reviewed the ArgoCD Application Controller logs:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100
   # Logs indicated: "Authentication failed for repository. Unauthorized (401)"
   ```

---

## 5. Root Cause
The credentials (Personal Access Token) configured in ArgoCD to access the private Git repository (`https://github.com/hariharan346/D-Var.git`) expired at 09:00 AM on 2026-06-19. This prevented the ArgoCD repository server from checking out the latest commits and comparing them to the cluster state.

---

## 6. Resolution
1. Generated a new GitHub Personal Access Token (PAT) with repository read permissions.
2. Updated the repository credentials in ArgoCD:
   ```bash
   argocd repo add https://github.com/hariharan346/D-Var.git --username developer --password <NEW_GITHUB_PAT> --overwrite
   ```
3. Forced a synchronization check:
   ```bash
   argocd app refresh payment-prod
   ```
4. Pods were successfully updated to `nginx:v2` and status returned to `Synced` & `Healthy`.

---

## 7. Prevention
- **Automated Alerts**: Configure Slack or PagerDuty alerts on ArgoCD connection errors and `ComparisonError` status flags.
- **Token Lifecycle Management**: Move repository credentials authentication to SSH Keys instead of Personal Access Tokens, or rotate tokens using HashiCorp Vault.
- **Monitoring**: Implement Prometheus metrics alerting on `gitops_sync_failure_total`.
