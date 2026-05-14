#!/bin/bash

set -e

echo "========================================="
echo "  Deploying Satisfactory to Kubernetes"
echo "========================================="
echo ""

NAMESPACE="satisfactory"

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
echo "Step 3: Deploying Satisfactory server..."
kubectl apply -f satisfactory.yaml

echo ""
echo "Waiting for pod to start (first run downloads ~5 GB via Steam, this takes a while)..."
kubectl wait --for=condition=ready pod -l app=satisfactory -n $NAMESPACE --timeout=600s

echo ""
echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""
echo "Get the assigned LoadBalancer IP:"
echo "  kubectl get svc satisfactory-svc -n $NAMESPACE"
echo ""
echo "Connect in Satisfactory via: <IP>:7777"
echo ""
echo "View logs:"
echo "  kubectl logs -f deployment/satisfactory -n $NAMESPACE"
echo ""
