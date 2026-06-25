# Exercise 2 – IAM / IRSA Failure Lab Manual

## Goal

Understand and troubleshoot:

Pod
↓
ServiceAccount
↓
IRSA Role
↓
DynamoDB

Incident:

Application cannot access DynamoDB.

Error:

arn:aws:sts::123456789012:assumed-role/eks-nodegroup-role

AccessDeniedException

---

# Folder Structure

irsa-lab/

├── serviceaccount-good.yaml

├── serviceaccount-broken.yaml

├── deployment.yaml

└── README.md

---

# Phase 1 - Start Kubernetes

Create cluster:
k3d cluster delete irsa-lab

k3d cluster create irsa-lab --api-port 127.0.0.1:6550


Verify:

kubectl cluster-info

kubectl get nodes

Expected:

k3d-irsa-lab-server-0 Ready

---

# Phase 2 - Deploy Working Configuration

Apply ServiceAccount:

kubectl apply -f serviceaccount-good.yaml

Apply Deployment:

kubectl apply -f deployment.yaml

Verify:

kubectl get sa

kubectl get pods

---

# Phase 3 - Investigate Working State

Check ServiceAccount:

kubectl get sa app-sa -o yaml

Expected:

annotations:
eks.amazonaws.com/role-arn: arn:aws:iam::660201001952:role/dynamodb-irsa-role

Check Pod:

kubectl get pods

kubectl describe pod <pod-name>

Expected:

Service Account: app-sa

Conclusion:

IRSA configured correctly.

---

# Phase 4 - Simulate Failure

Apply broken configuration:

kubectl apply -f serviceaccount-broken.yaml

Verify:

kubectl get sa app-sa -o yaml

Expected:

No annotation present.

Restart application:

kubectl delete pod -l app=customer-app

Verify:

kubectl get pods

---

# Phase 5 - Troubleshooting Process

Question 1:

Why node role is being used?

Answer:

Pod failed to obtain IRSA credentials.

AWS SDK falls back to node credentials.

Evidence:

arn:aws:sts::123456789012:assumed-role/eks-nodegroup-role

---

Question 2:

Why IRSA is not working?

Checks:

kubectl get sa app-sa -o yaml

kubectl describe pod <pod-name>

Possible Causes:

1. Missing ServiceAccount annotation
2. Wrong ServiceAccount
3. IAM trust policy issue
4. Missing OIDC provider
5. Pod restart required

Lab Root Cause:

Missing ServiceAccount annotation.

---

Question 3:

How to fix?

Apply good ServiceAccount:

kubectl apply -f serviceaccount-good.yaml

Restart application:

kubectl delete pod -l app=customer-app

Verify:

kubectl get sa app-sa -o yaml

Annotation should return.

---

# Real EKS Verification

Inside Pod:

aws sts get-caller-identity

If output shows:

assumed-role/my-irsa-role

IRSA Working

If output shows:

assumed-role/eks-nodegroup-role

IRSA Broken

---

# Interview Flow (2 Minutes)

1. Check logs.
2. Identify node role usage.
3. Check ServiceAccount annotation.
4. Check pod ServiceAccount.
5. Determine root cause.
6. Restore annotation.
7. Restart pod.
8. Verify IRSA role assumption.

---

# Commands Cheat Sheet

kubectl cluster-info

kubectl get nodes

kubectl get pods

kubectl get sa

kubectl describe pod <pod-name>

kubectl get sa app-sa -o yaml

kubectl apply -f serviceaccount-good.yaml

kubectl apply -f serviceaccount-broken.yaml

kubectl delete pod -l app=customer-app

aws sts get-caller-identity
# ex-2-IAM-IRSA-Failure
# ex-2-IAM-IRSA-Failure
