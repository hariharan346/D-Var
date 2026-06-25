# 🛡️ Exercise 17: Implement IRSA for Application Access

A step-by-step guide to configuring **IAM Roles for Service Accounts (IRSA)** in Amazon EKS. This setup enables Kubernetes applications to securely access AWS DynamoDB using temporary web-identity credentials, avoiding the risk of hardcoded AWS Access/Secret Keys.

---

## 🏗️ Architecture Flow

```text
┌────────────────────────────────────────────────────────┐
│                     Application Pod                    │
└──────────────────────────┬─────────────────────────────┘
                           │ (assumes identity via)
                           ▼
┌────────────────────────────────────────────────────────┐
│               Kubernetes ServiceAccount                │
└──────────────────────────┬─────────────────────────────┘
                           │ (federated via OIDC with)
                           ▼
┌────────────────────────────────────────────────────────┐
│                    IAM Role (IRSA)                     │
└──────────────────────────┬─────────────────────────────┘
                           │ (granted access via)
                           ▼
┌────────────────────────────────────────────────────────┐
│                       IAM Policy                       │
└──────────────────────────┬─────────────────────────────┘
                           │ (authorizes actions on)
                           ▼
┌────────────────────────────────────────────────────────┐
│                    Amazon DynamoDB                     │
└────────────────────────────────────────────────────────┘
```

> [!NOTE]
> Under IRSA, the EKS mutating admission controller automatically injects AWS credentials and token files (`AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE`) into the pods associated with the annotated `ServiceAccount`.

---

## ⚡ Prerequisites

Before starting, ensure you have the following tools and resources ready:

* ☸️ **Amazon EKS Cluster** up and running
* 🔧 **kubectl** installed and configured to connect to your cluster
* 🛠️ **eksctl** installed
* ☁️ **AWS CLI** authenticated with administrative permissions
* 🗄️ **Amazon DynamoDB** service access

---

## 🚀 Step-by-Step Implementation

### Step 1: Verify EKS Cluster Connectivity
Verify that your EKS cluster is active and `kubectl` is communicating properly:
```bash
kubectl get nodes
```
*Expected Output:*
```text
NAME                                           STATUS   ROLES    AGE
ip-192-168-xx-xx.ap-south-1.compute.internal   Ready    <none>   xxm
ip-192-168-yy-yy.ap-south-1.compute.internal   Ready    <none>   xxm
```

---

### Step 2: Create DynamoDB Table
Provision the `users` DynamoDB table using the following CLI command:
```bash
aws dynamodb create-table \
  --table-name users \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

To confirm the table creation:
```bash
aws dynamodb describe-table --table-name users
```

---

### Step 3: Configure OIDC Provider
IRSA relies on an OpenID Connect (OIDC) provider. Retrieve your EKS cluster's OIDC issuer URL:
```bash
aws eks describe-cluster \
  --name irsa-cluster \
  --region ap-south-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text
```
*Example Output:*
`https://oidc.eks.ap-south-1.amazonaws.com/id/E89FB241B06BFE763AE6937D7B0853CA`

Associate the IAM OIDC provider with your EKS cluster:
```bash
eksctl utils associate-iam-oidc-provider \
  --cluster irsa-cluster \
  --region ap-south-1 \
  --approve
```

---

### Step 4: Create IAM Policy
Define an IAM policy that allows read and write actions on the `users` table.

Create a file named `dynamodb-policy.json`:
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
      "Resource": "arn:aws:dynamodb:ap-south-1:660201001952:table/users"
    }
  ]
}
```

Register the policy in your AWS account:
```bash
aws iam create-policy \
  --policy-name DynamoDBIRSAPolicy \
  --policy-document file://dynamodb-policy.json
```
*Expected Policy ARN:* `arn:aws:iam::660201001952:policy/DynamoDBIRSAPolicy`

---

### Step 5: Create IAM Service Account
Create the Kubernetes `ServiceAccount` and bind it to a new AWS IAM Role using `eksctl`:
```bash
eksctl create iamserviceaccount \
  --cluster irsa-cluster \
  --region ap-south-1 \
  --namespace default \
  --name dynamodb-sa \
  --attach-policy-arn arn:aws:iam::660201001952:policy/DynamoDBIRSAPolicy \
  --approve
```

Verify that the `ServiceAccount` was created and carries the role annotation:
```bash
kubectl get sa dynamodb-sa -o yaml
```
*Expected Annotation:*
```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::660201001952:role/eksctl-irsa-cluster-addon-iamserviceaccount-d-Role1-LMNvsml8i4E1
```

---

### Step 6: Deploy Test Pod
Create a deployment pod manifest `irsa-test.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: irsa-test
spec:
  serviceAccountName: dynamodb-sa
  containers:
  - name: aws-cli
    image: amazon/aws-cli
    command: ["sleep","3600"]
```

Apply the manifest to launch the pod:
```bash
kubectl apply -f irsa-test.yaml
```

Ensure the pod is in a `Running` status:
```bash
kubectl get pods
```

---

### Step 7: Verify IRSA Authentication
Execute the AWS STS identity check command inside the running pod. It should display the assumed IAM Role from our service account:
```bash
kubectl exec -it irsa-test -- aws sts get-caller-identity
```
*Expected Output:*
```json
{
  "Account": "660201001952",
  "Arn": "arn:aws:sts::660201001952:assumed-role/eksctl-irsa-cluster-addon-iamserviceaccount-d-Role1-LMNvsml8i4E1/botocore-session-1782293400"
}
```

> [!TIP]
> Notice that no static secret keys or credentials were configured. Under the hood, a temporary Web Identity Token is being used automatically.

---

### Step 8: Test DynamoDB operations

#### ➕ Insert an Item (PutItem)
```bash
kubectl exec -it irsa-test -- \
aws dynamodb put-item \
  --table-name users \
  --item '{"id":{"S":"1"},"name":{"S":"Hari"}}' \
  --region ap-south-1
```

#### 🔍 Retrieve the Item (GetItem)
```bash
kubectl exec -it irsa-test -- \
aws dynamodb get-item \
  --table-name users \
  --key '{"id":{"S":"1"}}' \
  --region ap-south-1
```
*Response:*
```json
{
  "Item": {
    "id": {
      "S": "1"
    },
    "name": {
      "S": "Hari"
    }
  }
}
```

#### ✏️ Update the Item (UpdateItem)
```bash
kubectl exec -it irsa-test -- \
aws dynamodb update-item \
  --table-name users \
  --key '{"id":{"S":"1"}}' \
  --update-expression "SET #n = :v" \
  --expression-attribute-names '{"#n":"name"}' \
  --expression-attribute-values '{":v":{"S":"Hari Updated"}}' \
  --region ap-south-1
```

Verify that the update took effect:
```bash
kubectl exec -it irsa-test -- \
aws dynamodb get-item \
  --table-name users \
  --key '{"id":{"S":"1"}}' \
  --region ap-south-1
```
*Updated Response:*
```json
{
  "Item": {
    "id": {
      "S": "1"
    },
    "name": {
      "S": "Hari Updated"
    }
  }
}
```

---

## 📊 Validation Matrix

| Test Case | Description | Status |
| :--- | :--- | :---: |
| 🛡️ **OIDC Configured** | IAM OIDC Provider is associated with the EKS Cluster | **PASS** ✅ |
| 📋 **IAM Policy Created** | Policy generated allowing DynamoDB action rules | **PASS** ✅ |
| 🔑 **IAM Role Created** | IAM Role created with WebIdentity trust policy | **PASS** ✅ |
| 👤 **ServiceAccount Config** | ServiceAccount annotated with correct IAM Role | **PASS** ✅ |
| 🔐 **IRSA Authentication** | STS identity confirms assumed role inside pod | **PASS** ✅ |
| 📥 **DynamoDB PutItem** | Item successfully inserted via pod console | **PASS** ✅ |
| 📤 **DynamoDB GetItem** | Item successfully retrieved via pod console | **PASS** ✅ |
| 🔄 **DynamoDB UpdateItem** | Item successfully updated via pod console | **PASS** ✅ |
| 🚫 **No AWS Access Keys** | Authentication uses only temporary Web Identity tokens | **PASS** ✅ |

---

## 🎯 Conclusion
By mapping a Kubernetes ServiceAccount to an AWS IAM Role via EKS OIDC, applications can access AWS resources dynamically and securely. This follows the principle of least privilege and avoids the security risk of storing credentials in configuration files or container images.
