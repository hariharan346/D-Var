Exercise 22 - Horizontal Pod Autoscaler (HPA) + Cluster Autoscaler on AWS EKS
Objective

Implement automatic scaling in Kubernetes.

Requirements
1. Horizontal Pod Autoscaler (HPA)
2. Cluster Autoscaler
3. Load Testing
4. Pod Scaling: 2 → 20
5. Node Scaling: 3 → 6
Architecture
                    Load Generator
                           |
                           v
                  +----------------+
                  |   cpu-demo App |
                  +----------------+
                           |
                           v
                     HPA Monitors
                           |
                    CPU > 50%
                           |
                           v
                Increase Pod Replicas
                           |
                    Pods Pending
                           |
                           v
               Cluster Autoscaler
                           |
                           v
                Increase Node Count
                           |
                           v
                     AWS ASG Scale
                           |
                           v
                    New EC2 Nodes
Prerequisites
Local Machine

Installed:

aws --version
kubectl version --client
eksctl version

Configured AWS:

aws configure

Verify:

aws sts get-caller-identity
Step 1 - Create EKS Cluster
Cluster Configuration
Cluster Name : ex22-cluster
Region       : ap-south-1
Node Count   : 3
Instance Type: t3.small
Min Nodes    : 3
Max Nodes    : 6

Create cluster:

eksctl create cluster \
  --name ex22-cluster \
  --region ap-south-1 \
  --nodes 3 \
  --node-type t3.small \
  --managed

Verify:

kubectl get nodes

Expected:

3 Ready Nodes
Step 2 - Metrics Server

Install:

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

Verify:

kubectl top nodes

Expected:

CPU
Memory
Metrics Available
Step 3 - Deploy Sample Application

File:

cpu-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cpu-demo
  template:
    metadata:
      labels:
        app: cpu-demo
    spec:
      containers:
      - name: cpu-demo
        image: k8s.gcr.io/hpa-example
        resources:
          requests:
            cpu: 100m
          limits:
            cpu: 500m
---
apiVersion: v1
kind: Service
metadata:
  name: cpu-demo
spec:
  selector:
    app: cpu-demo
  ports:
  - port: 80
  type: LoadBalancer

Deploy:

kubectl apply -f cpu-app.yaml

Verify:

kubectl get pods
kubectl get svc
Step 4 - Create HPA

Create:

kubectl autoscale deployment cpu-demo \
  --cpu-percent=50 \
  --min=2 \
  --max=20

Verify:

kubectl get hpa

Expected:

Min Pods : 2
Max Pods : 20
Target CPU : 50%
Step 5 - Configure OIDC

Associate OIDC:

eksctl utils associate-iam-oidc-provider \
  --cluster ex22-cluster \
  --region ap-south-1 \
  --approve
Step 6 - Create IAM Service Account

Create:

eksctl create iamserviceaccount \
  --cluster=ex22-cluster \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --attach-policy-arn=arn:aws:iam::aws:policy/AutoScalingFullAccess \
  --override-existing-serviceaccounts \
  --approve \
  --region ap-south-1

Verify:

kubectl get sa cluster-autoscaler -n kube-system
Step 7 - Tag Auto Scaling Group

Enable Cluster Autoscaler discovery:

aws autoscaling create-or-update-tags \
--tags ResourceId=<ASG_NAME>,ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/enabled,Value=true,PropagateAtLaunch=true
aws autoscaling create-or-update-tags \
--tags ResourceId=<ASG_NAME>,ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/ex22-cluster,Value=owned,PropagateAtLaunch=true
Step 8 - Install Cluster Autoscaler

Deploy Cluster Autoscaler.

Key settings:

Min Nodes : 3
Max Nodes : 6
Cloud Provider : AWS

Verify:

kubectl get pods -n kube-system

Expected:

cluster-autoscaler Running
Step 9 - Fix RBAC

Issue encountered:

cannot list nodes
cannot acquire lease

Solution:

Created:

ClusterRole
ClusterRoleBinding

and bound:

cluster-autoscaler

service account.

Verify:

kubectl logs -n kube-system deployment/cluster-autoscaler

Expected:

Starting main loop
No unschedulable pods
Step 10 - Generate Load

Created load generator:

kubectl run load-generator \
  --image=busybox:1.35 \
  --restart=Never \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "load-generator",
      "image": "busybox:1.35",
      "command": ["/bin/sh","-c"],
      "args": ["while true; do wget -q -O- http://cpu-demo; done"]
    }]
  }
}'

Verify:

kubectl get pods

Expected:

load-generator Running
Step 11 - Force Scheduling Pressure

Increase resource requests:

kubectl set resources deployment cpu-demo \
  --requests=cpu=800m,memory=128Mi \
  --limits=cpu=1000m,memory=256Mi

Scale deployment:

kubectl scale deployment cpu-demo --replicas=20
Step 12 - Observe HPA & Cluster Autoscaler

Check:

kubectl get pods

Observed:

Many Pods = Pending

Reason:

Cluster lacks resources

Cluster Autoscaler action:

Pending Pods Detected
↓
Scale ASG
↓
Launch New EC2
↓
Join Cluster
↓
Schedule Pending Pods

Verify:

kubectl get nodes

Observed:

Initial Nodes = 3
Scaled Nodes  = 4+
Troubleshooting Faced
Issue 1
Metrics API not available

Solution:

Fixed metrics-server service selector
Issue 2
Cluster Autoscaler CrashLoopBackOff

Solution:

Added RBAC
Added Lease permissions
Issue 3
Load Generator StartError

Reason:

Git Bash converted /bin/sh
to Windows path

Solution:

Used JSON overrides
Final Outcome
✓ EKS Cluster Created
✓ Metrics Server Installed
✓ HPA Configured
✓ Cluster Autoscaler Installed
✓ Load Generated
✓ Pods Scaled
✓ Pending Pods Created
✓ New Node Provisioned
✓ Node Scaling Verified
Cleanup

VERY IMPORTANT

Delete cluster after testing:

eksctl delete cluster \
  --name ex22-cluster \
  --region ap-south-1

This is the exact documentati"# ex23-hpa" 
