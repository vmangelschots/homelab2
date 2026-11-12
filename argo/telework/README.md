# Teleworkchecker

A small Django app to track where you worked each day (home, office, elsewhere,
half/half, or not worked) and see per-month and per-year statistics on your
telework percentage — handy for keeping an eye on a "max 50% telework" rule.

**Source / image:** [ghcr.io/vmangelschots/teleworkchecker](https://ghcr.io/vmangelschots/teleworkchecker) (private — built by CI on every push to main)

## Architecture

- **web** — Django + Gunicorn + WhiteNoise, single replica
- **postgres** — PostgreSQL 17, 5Gi iSCSI (`truenas-iscsi`)
- **Ingress** — Traefik, TLS via `letsencrypt-dns01`
- Migrations run automatically in the `web` Deployment's initContainer on every
  rollout (it waits for postgres, then runs `manage.py migrate --noinput`).

## Prerequisites (once, before the first apply)

1. **Secrets:** copy `secret.yaml.example` to `secret.yaml`, fill in real
   values, then `kubectl apply -f secret.yaml`.

   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(50))"   # SECRET_KEY
   openssl rand -base64 32 | tr '+/' '-_'                          # POSTGRES_PASSWORD
   ```

2. **Pull secret:** the ghcr.io image is private. Create a pull secret with a
   GitHub PAT that has `read:packages`:

   ```bash
   kubectl create secret docker-registry ghcr-pull -n telework \
     --docker-server=ghcr.io --docker-username=vmangelschots \
     --docker-password=<PAT>
   ```

3. **After first deploy**, create a login:

   ```bash
   kubectl exec -n telework deploy/web -it -- python manage.py createsuperuser
   ```

## Deployment

```bash
cd argo/telework
./deploy.sh
```

Or manually:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f pvc.yaml
kubectl apply -f secret.yaml
# create ghcr-pull secret, see above
kubectl apply -f postgres.yaml
kubectl apply -f telework.yaml
```

## Configuration

The app reads config from environment variables (set in `telework.yaml` /
`secret.yaml`):

| Variable | Value here | Description |
|---|---|---|
| `SECRET_KEY` | from `telework-secrets` | Django secret key |
| `DEBUG` | `false` | Debug mode off in production |
| `ALLOWED_HOSTS` | `telework.mangelschots.org` | Allowed hostname |
| `DATABASE_ENGINE` | `postgres` | Use the postgres backend |
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | from `telework-secrets` | DB credentials |
| `POSTGRES_HOST` | `postgres` | In-cluster service name |
| `POSTGRES_PORT` | `5432` | Default postgres port |

## Access

<https://telework.mangelschots.org>

Django admin is available at `/admin/`.

## Management

```bash
# View logs
kubectl logs -f deployment/web -n telework

# Run a management command
kubectl exec -n telework deploy/web -it -- python manage.py <command>

# Restart (e.g. to pick up a new image)
kubectl rollout restart deployment/web -n telework

# Status
kubectl get all -n telework
```

## Upgrading

```bash
kubectl rollout restart deployment/web -n telework
```

The initContainer re-runs `migrate --noinput` on every rollout, so schema
changes are picked up automatically.

## Uninstall

```bash
kubectl delete namespace telework
# PVC is retained (truenas-iscsi) — delete manually if you want to remove data:
# kubectl delete pvc postgres-data -n telework
```
