# AWS EKS IRSA (IAM Roles for Service Accounts) with DynamoDB Setup Guide

This document details the configuration and commands used to set up secure, credential-less access to DynamoDB from a Python application running in Amazon EKS using IAM Roles for Service Accounts (IRSA).

---

## 1. DynamoDB Table Creation

The `users` table was created with a primary key partition (`id`) of type String (`S`).

### CLI Command:
```bash
aws dynamodb create-table \
  --table-name users \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Table Details:
- **Table Name**: `users`
- **ARN**: `arn:aws:dynamodb:ap-south-1:660201001952:table/users`
- **Region**: `ap-south-1`
- **Billing Mode**: `PAY_PER_REQUEST`

---

## 2. IAM Policy Setup

We created the local IAM Policy definition in [dynamodb-policy.json](file:///e:/games/ex17/dynamodb-policy.json) and registered it in AWS.

### Policy Document (`dynamodb-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/users"
    }
  ]
}
```

### Register Policy Command:
```bash
aws iam create-policy \
  --policy-name DynamoDBIRSAPolicy \
  --policy-document file://dynamodb-policy.json
```

### Output:
- **Policy Name**: `DynamoDBIRSAPolicy`
- **ARN**: `arn:aws:iam::660201001952:policy/DynamoDBIRSAPolicy`

---

## 3. OIDC Provider Validation

To verify or associate the OIDC provider for your EKS Cluster:

1. **Retrieve EKS Cluster OIDC URL**:
   ```bash
   aws eks describe-cluster \
     --name demo-cluster \
     --query "cluster.identity.oidc.issuer" \
     --output text
   ```
   *Expected result is in format:* `https://oidc.eks.ap-south-1.amazonaws.com/id/XXXX`

2. **List Registered OIDC Providers**:
   ```bash
   aws iam list-open-id-connect-providers
   ```

3. **Associate if Missing**:
   ```bash
   eksctl utils associate-iam-oidc-provider \
     --cluster demo-cluster \
     --approve
   ```

---

## 4. Trust Relationship Configuration

A trust policy template [trust-policy.json](file:///e:/games/ex17/trust-policy.json) has been configured. When configuring for a cluster, replace `OIDC_ID` with the cluster's OIDC identifier.

### Trust Document (`trust-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::660201001952:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/OIDC_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-south-1.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:default:dynamodb-sa"
        }
      }
    }
  ]
}
```

---

## 5. IAM Role Creation & Policy Attachment

We created the IAM Role `DynamoDBIRSARole` and attached the policy.

### Create Role Command:
```bash
aws iam create-role \
  --role-name DynamoDBIRSARole \
  --assume-role-policy-document file://trust-policy.json
```

### Attach Policy Command:
```bash
aws iam attach-role-policy \
  --role-name DynamoDBIRSARole \
  --policy-arn arn:aws:iam::660201001952:policy/DynamoDBIRSAPolicy
```

- **IAM Role ARN**: `arn:aws:iam::660201001952:role/DynamoDBIRSARole`

---

## 6. Kubernetes Manifests & Application Setup

The configuration files are saved in the project workspace:

1. **ServiceAccount Manifest**: [serviceaccount.yaml](file:///e:/games/ex17/serviceaccount.yaml)
   Annotates the service account with the IAM Role ARN.
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: dynamodb-sa
     namespace: default
     annotations:
       eks.amazonaws.com/role-arn: arn:aws:iam::660201001952:role/DynamoDBIRSARole
   ```

2. **Python App**: [app.py](file:///e:/games/ex17/app.py)
   Uses `boto3` to perform DynamoDB operations using default credentials chain.

3. **Dockerfile**: [Dockerfile](file:///e:/games/ex17/Dockerfile)
   Packages the Python application and installs dependencies.

4. **Deployment Manifest**: [deployment.yaml](file:///e:/games/ex17/deployment.yaml)
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: dynamodb-app
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: dynamodb-app
     template:
       metadata:
         labels:
           app: dynamodb-app
       spec:
         serviceAccountName: dynamodb-sa
         containers:
         - name: app
           image: <dockerhub-user>/dynamodb-irsa:latest
   ```

---

## 7. Verification Steps & Troubleshooting

### Apply Manifests
```bash
kubectl apply -f serviceaccount.yaml
kubectl apply -f deployment.yaml
```

### Verify service account annotation
```bash
kubectl get sa dynamodb-sa -o yaml
```

### Verify Pod Environment Variables
```bash
kubectl describe pod <pod-name>
```
Ensure that the mutating webhook has injected:
- `AWS_ROLE_ARN=arn:aws:iam::660201001952:role/DynamoDBIRSARole`
- `AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token`

### Execute Verification inside Pod
```bash
kubectl exec -it <pod-name> -- env | grep AWS
kubectl exec -it <pod-name> -- aws sts get-caller-identity
```
Expected caller identity response:
```json
{
  "Arn": "arn:aws:sts::660201001952:assumed-role/DynamoDBIRSARole/..."
}
```

---

## Submission Checklist Status

* [x] DynamoDB table created (`arn:aws:dynamodb:ap-south-1:660201001952:table/users`)
* [x] IAM Policy created (`arn:aws:iam::660201001952:policy/DynamoDBIRSAPolicy`)
* [x] IAM Role created (`arn:aws:iam::660201001952:role/DynamoDBIRSARole`)
* [x] Local configuration files (`dynamodb-policy.json`, `trust-policy.json`, `serviceaccount.yaml`, `app.py`, `Dockerfile`, `deployment.yaml`) created successfully.
