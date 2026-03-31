#!/bin/bash

set -e

echo "========================================="
echo "  Deploying Ghostfolio to Kubernetes"
echo "========================================="
echo ""

NAMESPACE="ghostfolio"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found. Please install kubectl first."
    exit 1
fi

echo "Step 1: Creating namespace..."
kubectl apply -f namespace.yaml

echo ""
echo "Step 2: Creating secrets..."
if [ ! -f secret.yaml ]; then
    echo "Error: secret.yaml not found!"
    echo "Please copy secret.yaml.example to secret.yaml and update the values."
    exit 1
fi
kubectl apply -f secret.yaml

echo ""
echo "Step 3: Creating persistent volume claim..."
kubectl apply -f pvc.yaml

echo ""
echo "Step 4: Deploying PostgreSQL..."
kubectl apply -f postgres.yaml

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s

echo ""
echo "Step 5: Deploying Redis..."
kubectl apply -f redis.yaml

echo "Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=120s

echo ""
echo "Step 6: Deploying Ghostfolio application..."
kubectl apply -f ghostfolio.yaml

echo "Waiting for Ghostfolio to be ready..."
kubectl wait --for=condition=ready pod -l app=ghostfolio -n $NAMESPACE --timeout=300s

echo ""
echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""
echo "Ghostfolio is now running!"
echo ""
echo "Access your installation at:"
echo "  https://ghostfolio.mangelschots.org"
echo ""
echo "To check the status:"
echo "  kubectl get all -n $NAMESPACE"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/ghostfolio -n $NAMESPACE"
echo ""
echo "First-time setup:"
echo "  1. Navigate to https://ghostfolio.mangelschots.org"
echo "  2. Click 'Get Started' to create the first user"
echo "  3. The first user will automatically receive ADMIN role"
echo ""
