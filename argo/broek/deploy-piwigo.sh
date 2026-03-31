#!/bin/bash

set -e

echo "========================================="
echo "  Deploying Piwigo to Kubernetes"
echo "========================================="
echo ""

NAMESPACE="broek"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found. Please install kubectl first."
    exit 1
fi

echo "Step 1: Creating namespace..."
kubectl apply -f namespace.yaml

echo ""
echo "Step 2: Creating secrets..."
if [ ! -f piwigo-secret.yaml ]; then
    echo "Error: piwigo-secret.yaml not found!"
    echo "Please copy piwigo-secret.yaml.example to piwigo-secret.yaml and update the values."
    echo ""
    echo "Generate secure passwords with:"
    echo "  openssl rand -base64 24"
    exit 1
fi
kubectl apply -f piwigo-secret.yaml

echo ""
echo "Step 3: Creating persistent volume claims..."
kubectl apply -f piwigo-pvc.yaml

echo ""
echo "Step 4: Deploying MySQL database..."
kubectl apply -f piwigo-mysql.yaml

echo "Waiting for MySQL to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=piwigo-mysql -n $NAMESPACE --timeout=300s

echo ""
echo "Step 5: Deploying Piwigo application..."
kubectl apply -f piwigo.yaml

echo "Waiting for Piwigo to be ready..."
kubectl wait --for=condition=ready pod -l app=piwigo -n $NAMESPACE --timeout=300s

echo ""
echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""
echo "Piwigo is now running!"
echo ""
echo "Access your installation at:"
echo "  https://broek-fotos.mangelschots.org"
echo ""
echo "Database connection details for setup wizard:"
echo "  Database Host: piwigo-mysql-svc"
echo "  Database Name: piwigo"
echo "  Database User: piwigo"
echo "  Database Password: (use password from piwigo-secret.yaml)"
echo ""
echo "To check the status:"
echo "  kubectl get all -n $NAMESPACE"
echo ""
echo "To view Piwigo logs:"
echo "  kubectl logs -f deployment/piwigo -n $NAMESPACE"
echo ""
echo "To view MySQL logs:"
echo "  kubectl logs -f deployment/piwigo-mysql -n $NAMESPACE"
echo ""
