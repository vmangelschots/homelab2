#!/bin/sh
set -e
cd "$(dirname "$0")"

[ -f secret.yaml ] || { echo "secret.yaml missing - copy secret.yaml.example and fill it in"; exit 1; }

kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml -f configmap.yaml -f pvc.yaml
kubectl apply -f postgres.yaml
kubectl -n reconciled rollout status deploy/postgres --timeout=180s
kubectl apply -f reconciled.yaml
kubectl -n reconciled rollout status deploy/reconciled-backend --timeout=300s
kubectl -n reconciled rollout status deploy/reconciled-frontend --timeout=120s
