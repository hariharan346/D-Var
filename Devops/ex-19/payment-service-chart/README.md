# Payment Service Helm Chart

This is a reusable Helm chart to deploy our `payment-service` application to Kubernetes. It supports our development (`dev`), testing (`qa`), and production (`prod`) environments with custom configuration values for each.

---

## How to Run This Lab (Step-by-Step)

Here is how you can set up, run, and test this Helm chart yourself.

### Step 1: Open your terminal and go to the chart folder
Change your directory to the folder where the Helm chart files are:
```bash
cd payment-service-chart
```

### Step 2: Check for any syntax errors (Linting)
Run this command to make sure there are no typos or errors in the Helm templates:
```bash
helm lint .
```
If everything is correct, you will see a message saying `0 chart(s) failed`.

### Step 3: Test rendering the files locally (Dry-run)
You can see exactly what Kubernetes configuration files Helm will generate for each environment without actually deploying them:

* **For Dev environment:**
  ```bash
  helm template payment-service . -f values-dev.yaml
  ```
* **For QA environment:**
  ```bash
  helm template payment-service . -f values-qa.yaml
  ```
* **For Prod environment:**
  ```bash
  helm template payment-service . -f values-prod.yaml
  ```

### Step 4: Deploy to your Kubernetes cluster
Use one of these commands to install the chart on your cluster depending on which environment you are targetting:

* **To deploy to Dev:**
  ```bash
  helm install payment-service . -f values-dev.yaml
  ```
* **To deploy to QA:**
  ```bash
  helm install payment-service . -f values-qa.yaml
  ```
* **To deploy to Prod:**
  ```bash
  helm install payment-service . -f values-prod.yaml
  ```

### Step 5: Check if everything is running correctly
Run these commands to see your running applications, configurations, and load balancers:

1. **Check your running application pods:**
   ```bash
   kubectl get deployment
   ```
2. **Check the internal network service:**
   ```bash
   kubectl get service
   ```
3. **Check the external domain routing (Ingress):**
   ```bash
   kubectl get ingress
   ```
4. **Check the automatic scaling rules (HPA):**
   ```bash
   kubectl get hpa
   ```

### Step 6: How to update or rollback your application
If you make a change to the configuration and want to apply it:
```bash
helm upgrade payment-service . -f values-prod.yaml
```

If you made a mistake and want to go back to the first version:
```bash
helm rollback payment-service 1
```

### Step 7: How to clean up and delete everything
When you are done with the lab, you can delete all the created resources using:
```bash
helm uninstall payment-service
```

---

## Chart Directory Layout

Here is a quick look at the files we have in this project:

```
payment-service-chart/
├── Chart.yaml             # Metadata about this Helm chart
├── values.yaml            # Default configuration settings
├── values-dev.yaml        # Settings for the Dev environment (1 replica, small resources, no ingress)
├── values-qa.yaml         # Settings for the QA environment (2 replicas, medium resources, ingress enabled)
├── values-prod.yaml       # Settings for the Prod environment (3 replicas, large resources, ingress & autoscaling enabled)
├── templates/             # Kubernetes template files
│   ├── _helpers.tpl       # Shared template helpers for naming and labels
│   ├── configmap.yaml     # Application configuration settings
│   ├── deployment.yaml    # Manages our application pods and resources
│   ├── hpa.yaml           # Automatically scales pods up/down
│   ├── ingress.yaml       # Manages external access/domains (Nginx or AWS ALB)
│   ├── NOTES.txt          # Guide printed after helm install runs
│   ├── secret.yaml        # Holds secure secrets (DB username, password, JWT keys)
│   ├── service.yaml       # Connects traffic internally to our pods
│   └── serviceaccount.yaml# Sets up security privileges for the pods
└── README.md              # This guide
```

---

## Templates Explained

- **`deployment.yaml`**: Creates the application pods. It handles replica count, configures CPU/Memory limits, sets up health probes (liveness/readiness), and loads all ConfigMap and Secret values as environment variables.
- **`service.yaml`**: Exposes the application pods internally on a stable port.
- **`ingress.yaml`**: Routes external traffic into the service, supporting custom domains, TLS security, and AWS ALB load balancer annotations.
- **`configmap.yaml`**: Stores non-sensitive settings (like log levels and provider names).
- **`secret.yaml`**: Safely base64 encodes sensitive credentials (`DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`).
- **`hpa.yaml`**: Scales the number of pods dynamically based on CPU usage.
- **`serviceaccount.yaml`**: Provides an identity for the running pods.
- **`_helpers.tpl`**: Helps create standard naming and label structures.

---

## Configuration Options (`values.yaml`)

Here are the main configuration settings you can change in `values.yaml`:

| Key | Description | Default Value |
|---|---|---|
| `replicaCount` | The default number of running pods | `2` |
| `image.repository` | The docker container image to pull | `nginx` |
| `image.tag` | The tag/version of the docker image | `latest` |
| `resources` | CPU/Memory requests and limits | Requests: `100m`/`128Mi`, Limits: `500m`/`512Mi` |
| `ingress.enabled` | Enable/disable external domain access | `false` |
| `autoscaling.enabled`| Enable/disable automatic scaling | `false` |
| `configData` | Key-value settings for application config | See `values.yaml` |
| `secrets` | Sensitive credentials | See `values.yaml` |
