# Helm Upgrade Failure Lab: My Troubleshooting Journey (Immutable Field Error)

## 1. What is the Task?
I am troubleshooting a production deployment failure that occurs during a Helm upgrade. 

### The Incident I encountered
When I tried to upgrade my service named `payment-service`, my Helm upgrade command failed with this error:
```text
Error: UPGRADE FAILED: Deployment.apps "payment-service" is invalid: spec.selector: Invalid value: ...: field is immutable
```

### The Root Cause I discovered
I found out that the selector `spec.selector` in a Kubernetes Deployment is **immutable** (cannot be changed after creation). 
- My Version 1 chart used the selector `app: payment`
- My Version 2 chart attempted to change the selector to `app: payment-v2`

---

## 2. How I Started the Task (Reproducing the Error)

### Step 1: Clean Up Pre-existing Resources
First, I will make sure no legacy versions are running in my cluster:
```powershell
helm uninstall payment-service --ignore-not-found
kubectl delete deployment payment-service --ignore-not-found
kubectl delete service payment-service --ignore-not-found
```

### Step 2: Install Version 1 (Blue)
Next, I will install the initial version of my payment service:
```powershell
helm install payment-service ./chart-v1
```

I'll verify that the deployment was created successfully with the selector `app: payment`:
```powershell
kubectl get deployment payment-service -o jsonpath='{.spec.selector}'
```
*My Expected Output:* `{"matchLabels":{"app":"payment"}}`

### Step 3: Trigger the Error
Now, I will attempt to upgrade to Version 2 (which changes the selector to `app: payment-v2`) to reproduce the error:
```powershell
helm upgrade payment-service ./chart-v2
```
*The error I expect to see:*
```text
Error: UPGRADE FAILED: Deployment.apps "payment-service" is invalid: spec.selector: Invalid value: {"matchLabels":{"app":"payment-v2"}}: field is immutable
```

---

## 3. How I Fixed This: The Standard Way

If I do not need to change the selector name and want to update the image/resources standardly:

### Solution A: Keep the Selector Unchanged (Recommended)
1. I will open [chart-v2/values.yaml](file:///e:/AIVAR/Devops/ex-5/exercise-5-helm-upgrade-failure/chart-v2/values.yaml) and change `appName` back to match Version 1:
   ```yaml
   appName: payment
   ```
2. I will run the upgrade command again:
   ```powershell
   helm upgrade payment-service ./chart-v2
   ```

---

### Solution B: Force Recreate (If I must change the selector)
If changing the selector is mandatory for me, I have to delete the deployment so Helm can create a new one:
1. I will delete the deployment manually:
   ```powershell
   kubectl delete deployment payment-service
   ```
2. Then I will run the upgrade:
   ```powershell
   helm upgrade payment-service ./chart-v2
   ```

---

## 4. How I Fixed This: Blue-Green Deployment Way
To achieve zero downtime and completely avoid patching the immutable field in-place, I will deploy the new version as a separate release alongside the old one, and switch traffic.

### Step 1: Clean up my previous lab resources
```powershell
helm uninstall payment-service
```

### Step 2: Deploy "Blue" (Version 1)
```powershell
helm install payment-blue ./chart-v1 --set serviceName=payment-blue,appName=payment-blue
```

### Step 3: Deploy "Green" (Version 2)
I will deploy Version 2 alongside Version 1. Since it uses a different release name, there is no selector clash or patch error:
```powershell
helm install payment-green ./chart-v2 --set serviceName=payment-green,appName=payment-green
```

### Step 4: Route Traffic (The Switch)
1. I will create a router service pointing to my **Blue** environment:
   ```powershell
   kubectl expose deployment payment-blue --name=payment-router-service --port=80 --target-port=80
   ```
2. I will switch traffic to **Green** with zero downtime:
   ```powershell
   kubectl patch service payment-router-service -p '{"spec":{"selector":{"app":"payment-green"}}}'
   ```

### Step 5: Decommission "Blue"
Once I verify the Green environment is serving traffic correctly:
```powershell
helm uninstall payment-blue
```

---

## Clean Up All My Lab Resources
```powershell
helm uninstall payment-green --ignore-not-found
kubectl delete service payment-router-service --ignore-not-found
```
