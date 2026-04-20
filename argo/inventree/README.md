# InvenTree

Open-source inventory management system.

- URL: https://inventree.mangelschots.org
- Image: `inventree/inventree:stable`

## Components

| Component | Purpose |
|---|---|
| postgres | PostgreSQL 16 database (truenas-iscsi, 10Gi) |
| redis | Redis 7 cache |
| inventree-server | Django/gunicorn web server (port 8000) |
| inventree-worker | Background task worker (django-q) |

Both server and worker share the `inventree-data` NFS volume (20Gi) for media and static files.

## Deploy

```bash
# 1. Create secrets
cp secret.yaml.example secret.yaml
# Edit secret.yaml with generated values:
#   openssl rand -base64 32   → POSTGRES_PASSWORD, REDIS_PASSWORD
#   openssl rand -base64 64   → SECRET_KEY

kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml
kubectl apply -f pvc.yaml
kubectl apply -f postgres.yaml
kubectl apply -f redis.yaml
kubectl apply -f inventree.yaml
```

## First run

On first start InvenTree runs database migrations automatically. Once the server pod is ready, create the superuser:

```bash
kubectl exec -n inventree deploy/inventree-server -- invoke superuser
```
