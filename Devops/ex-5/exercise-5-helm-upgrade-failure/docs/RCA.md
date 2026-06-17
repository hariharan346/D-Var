# Root Cause Analysis (RCA) - Helm Upgrade Failure

## 1. Incident Summary & Symptoms
The upgrade of `payment-service` via `helm upgrade` failed immediately because Kubernetes rejected the changes. No downtime occurred as the active deployment was not modified.

## 2. Error Message
```text
UPGRADE FAILED: cannot patch Deployment: spec.selector: Invalid value: field is immutable
```

## 3. Investigation & Findings
- **Active Selector (V1):** `app: payment`
- **Target Selector (V2):** `app: payment-v2`
- **Finding:** The deployment failed because Helm tried to patch the existing deployment selector, which is not allowed.

## 4. Root Cause (Why Selectors are Immutable)
In Kubernetes, `spec.selector` is immutable after creation. If changed:
- Existing Pods would become orphaned (running untracked).
- The controller would launch new Pods.
To prevent this, the Kubernetes API server blocks any updates to the selector.

## 5. How to Fix
- **Standard Solution:** Revert the selector in `chart-v2/values.yaml` back to `app: payment` so it matches Version 1, then upgrade.
- **Recreation Solution (Downtime):** Delete the old deployment (`kubectl delete deployment payment-service`) and then run `helm upgrade`.
- **Blue-Green Solution (Zero Downtime):** Deploy Version 2 as a separate release (`payment-green`) and switch a router service's selector to point to it.

## 6. Long-Term Prevention
- Use neutral, static label selectors (e.g., `app: payment`).
- Avoid putting dynamic fields (like version numbers) in selectors.
- Run dry-runs (`helm upgrade --dry-run`) in CI/CD pipelines before deploying.
