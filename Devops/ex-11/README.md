# DevOps Lab: Kubernetes CrashLoopBackOff Resolution

This documentation records the details of the **Exercise 11: CrashLoopBackOff** production incident, how it was built, and how it was successfully resolved.

---

##  The Incident (What is the Task?)
The core service `payment-service` was constantly failing on startup and entering a `CrashLoopBackOff` status.

* **Symptom:**
  ```bash
  kubectl get pods
  # Output: payment-service-xxxx  0/1  CrashLoopBackOff
  ```

---

##  How We Built the Lab
We simulated a real production database connection failure:
1. **Python App (`app/`):** Created a startup script that connects to PostgreSQL using variables `DB_HOST`, `DB_PORT`, `DB_USER`, and `DB_PASSWORD`. On connection failure, it logs a `panic` and exits with code `1`.
2. **Docker Image:** Built the application container locally:
   ```bash
   docker build -t payment-service:latest ./app
   minikube image load payment-service:latest
   ```
3. **Database & Workload (`k8s/`):** Deployed a PostgreSQL Alpine instance and service on port `5432`, and injected configurations into the payment app using a ConfigMap and Secret.
4. **Trigger:** Set the `DB_PORT` in the ConfigMap to an incorrect port (`5433`) to intentionally trigger the crash.

---

##  How I Investigated It
We isolated the root cause using these debugging steps:

1. **Check Logs:**
   ```bash
   kubectl logs -l app=payment-service
   # Output: panic: dial tcp <IP>:5433: connection refused
   ```
   *Insight:* The application is trying to connect to port `5433` and failing.

2. **Verify Database Service Port:**
   ```bash
   kubectl get svc postgres
   # Output: postgres ... 5432/TCP
   ```
   *Insight:* The PostgreSQL database is actually listening on port **`5432`**.

3. **Check ConfigMap Parameters:**
   ```bash
   kubectl get configmap payment-config -o yaml
   # Output: DB_PORT: "5433"
   ```
   *Root Cause:* There is a port configuration mismatch in the ConfigMap (`5433` vs `5432`).

---

##  How I Solved It (The Fix)
To recover the payment service:

1. **Modify ConfigMap:** Opened [k8s/configmap.yaml](file:///e:/AIVAR/Devops/ex-11/k8s/configmap.yaml) and changed `DB_PORT` to `5432`.
2. **Apply Changes:**
   ```bash
   kubectl apply -f k8s/configmap.yaml
   ```
3. **Restart the Application:** Triggered a rollout restart to reload environment variables:
   ```bash
   kubectl rollout restart deployment payment-service
   ```
4. **Confirm Resolution:**
   ```bash
   kubectl get pods
   # Output: payment-service-xxxx  1/1  Running

   kubectl logs -l app=payment-service
   # Output: Connection successful! Running payment-service loop...
   ```
   *Result:* The pod stabilized and database connection was successfully established!
