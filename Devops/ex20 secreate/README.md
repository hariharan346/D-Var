# Exercise 20: External Secrets Integration

Quick step-by-step guide to integrating AWS Secrets Manager with Kubernetes using the External Secrets Operator.

---

## 1. Create the AWS Secret
1. Go to AWS Secrets Manager console in **`us-east-1`** (N. Virginia).
2. Store a new key-value secret named **`my-app-secrets`** containing:
   * `DB_USERNAME`
   * `DB_PASSWORD`
   * `JWT_SECRET`

---

## 2. Deploy Kubernetes Resources

### Step A: Create Kubernetes Secret
Deploy the AWS access credentials in the **same namespace** (`default`) as your application:
```bash
kubectl create secret generic awssm-secret \
  -n default \
  --from-literal=access-key=YOUR_ACCESS_KEY_ID_HERE \
  --from-literal=secret-access-key=YOUR_SECRET_ACCESS_KEY_HERE
```
***Gotcha:** Do not swap the keys! The Access Key ID (`AKIA...`) must go to `access-key`.*

### Step B: Create SecretStore (`secretstore.yaml`)
Create a namespaced SecretStore pointing to `us-east-1`:
```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secret-store
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: awssm-secret
            key: access-key
          secretAccessKeySecretRef:
            name: awssm-secret
            key: secret-access-key
```
Apply the manifest:
```bash
kubectl apply -f secretstore.yaml --validate=false
```

### Step C: Create ExternalSecret (`externalsecret.yaml`)
Configure the sync mappings:
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-secret
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: aws-secret-store
    kind: SecretStore
  target:
    name: app-secret
  data:
    - secretKey: DB_USERNAME
      remoteRef:
        key: my-app-secrets
        property: DB_USERNAME
    - secretKey: DB_PASSWORD
      remoteRef:
        key: my-app-secrets
        property: DB_PASSWORD
    - secretKey: JWT_SECRET
      remoteRef:
        key: my-app-secrets
        property: JWT_SECRET
```
Apply the manifest:
```bash
kubectl apply -f externalsecret.yaml --validate=false
```





---

## 3. Validation
Check that the sync status is ready and the Kubernetes secret is generated:
```bash
# Verify ExternalSecret status
kubectl get externalsecret app-secret

# Verify generated secret and its keys
kubectl describe secret app-secret
```

---

## Troubleshooting & Common Pitfalls

* **TLS Handshake Timeout:** Minikube resource lag can time out `kubectl` validation. Always add `--validate=false` to your apply commands.
* **Webhook Failures:** If webhooks hang on admission checks:
  ```bash
  kubectl delete validatingwebhookconfiguration secretstore-validate externalsecret-validate
  ```
* **Namespace Isolation:** Namespaced `SecretStore` resources can only access credentials secrets (`awssm-secret`) inside their **own namespace** (`default`). Ensure they are not isolated in `external-secrets`.
* **Region Mismatch:** Ensure the region configured in `secretstore.yaml` (`us-east-1`) matches the AWS region of your secret.
