#!/bin/bash

set -e

echo "========================================="
echo "  Deploying Teleworkchecker to Kubernetes"
echo "========================================="
echo ""

NAMESPACE="telework"

if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found."
    exit 1
fi

echo "Step 1: Creating namespace..."
kubectl apply -f namespace.yaml

echo ""
echo "Step 2: Creating persistent volume claim..."
kubectl apply -f pvc.yaml

echo ""
echo "Step 3: Applying secrets..."
if [ ! -f secret.yaml ]; then
    echo "Error: secret.yaml not found. Copy secret.yaml.example to secret.yaml and fill it in first."
    exit 1
fi
kubectl apply -f secret.yaml

echo ""
echo "Step 4: Checking for ghcr-pull image pull secret..."
if ! kubectl get secret ghcr-pull -n "$NAMESPACE" &> /dev/null; then
    echo "Error: secret ghcr-pull not found in namespace $NAMESPACE."
    echo "Create it with a GitHub PAT that has read:packages, e.g.:"
    echo "  kubectl create secret docker-registry ghcr-pull -n $NAMESPACE \\"
    echo "    --docker-server=ghcr.io --docker-username=vmangelschots \\"
    echo "    --docker-password=<PAT>"
    exit 1
fi

echo ""
echo "Step 5: Deploying PostgreSQL..."
kubectl apply -f postgres.yaml

echo ""
echo "Step 6: Deploying Teleworkchecker (runs migrations via initContainer)..."
kubectl apply -f telework.yaml

echo ""
echo "Waiting for pod to become ready..."
kubectl wait --for=condition=ready pod -l app=telework -n "$NAMESPACE" --timeout=180s

echo ""
echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""
echo "Create a login (first deploy only):"
echo "  kubectl exec -n $NAMESPACE deploy/web -it -- python manage.py createsuperuser"
echo ""
echo "App available at: https://telework.mangelschots.org"
