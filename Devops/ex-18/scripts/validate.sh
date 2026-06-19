#!/usr/bin/env bash
# Validation Script for ArgoCD GitOps Platform

echo "=== ArgoCD Application List ==="
argocd app list

echo ""
echo "=== ArgoCD App Details (payment-dev) ==="
argocd app get payment-dev --refresh

echo ""
echo "=== ArgoCD App Details (payment-qa) ==="
argocd app get payment-qa --refresh

echo ""
echo "=== ArgoCD App Details (payment-prod) ==="
argocd app get payment-prod --refresh

echo ""
echo "=== Kubernetes Deployments ==="
kubectl get deployments -A -l app=payment-service

echo ""
echo "=== Kubernetes Pods ==="
kubectl get pods -A -l app=payment-service
