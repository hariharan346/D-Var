# How I Solved It - Troubleshooting Notes

These are my personal notes and reflections on troubleshooting issues I encountered during the setup and testing of the GitOps platform.

---

### Issue 1: The Dev Application remained OutOfSync after manual drift

**What happened:**
I noticed that after making a manual change directly in the cluster to test the deployment, the application showed `OutOfSync` status in ArgoCD, and the changes were not automatically reverting.

**How I resolved it:**
1. First, I checked the current application configuration by running:
   ```bash
   argocd app get payment-dev
   ```
2. Looking closely at the output, I saw that under `Sync Policy`, it was set to `Automated (Prune: true, SelfHeal: false)`. The `SelfHeal` property was disabled!
3. I went to my `argocd/dev-app.yaml` file and saw that indeed `selfHeal` was omitted or set to `false`.
4. I updated `selfHeal: true` inside the manifest:
   ```yaml
   syncPolicy:
     automated:
       prune: true
       selfHeal: true
   ```
5. I committed the manifest change and pushed it:
   ```bash
   git add argocd/dev-app.yaml
   git commit -m "fix: enable self-heal policy for dev environment"
   git push origin main
   ```
6. The moment the controller synced, I scaled the deployment manually again, and observed that ArgoCD corrected the drift back to 1 replica in less than 5 seconds.

---

### Issue 2: ArgoCD could not find the target path

**What happened:**
When I initially created the QA application, the status showed a red `ComparisonError` with the message `path gitops/qa/payment-service not found in repository`.

**How I resolved it:**
1. I double-checked the folder structure of my workspace.
2. I realized that when I created the folders, I had a typo and named it `gitops/qa/paymnt-service/` (missing the 'e').
3. I renamed the directory to the correct spelling:
   ```bash
   mv gitops/qa/paymnt-service gitops/qa/payment-service
   ```
4. I committed the directory structure fix and pushed it:
   ```bash
   git add .
   git commit -m "fix: correct directory spelling for qa payment-service"
   git push origin main
   ```
5. I triggered a refresh via:
   ```bash
   argocd app refresh payment-qa
   ```
6. The status immediately turned green, and the sync successfully completed!

---

### Issue 3: Ingress controller routing configuration issues in Prod

**What happened:**
While testing the production routing path, traffic to `payment.production.local` kept returning `404 Not Found`.

**How I resolved it:**
1. I checked the service configurations using:
   ```bash
   kubectl get svc -n payment-prod
   ```
   The service was running fine on port 80.
2. Next, I inspected the ingress resource:
   ```bash
   kubectl describe ingress payment-service-ingress -n payment-prod
   ```
3. I noticed that the backend service port defined in my `ingress.yaml` was pointing to port `8080`, while the service port in `service.yaml` was configured to port `80`.
4. I modified `gitops/prod/payment-service/ingress.yaml` to point to port `80` correctly:
   ```yaml
   backend:
     service:
       name: payment-service
       port:
         number: 80
   ```
5. I pushed the change to main, let ArgoCD prune the old configuration, and verified the ingress mapping again. The 404 error was successfully resolved!
