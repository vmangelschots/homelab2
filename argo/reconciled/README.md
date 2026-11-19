# reconciled

Personal budgeting app ([vmangelschots/reconciled](https://github.com/vmangelschots/reconciled)):
Django REST backend, React frontend (nginx), PostgreSQL.

- **URL:** https://reconciled.mangelschots.org
- **Images:** `ghcr.io/vmangelschots/reconciled-backend`, `ghcr.io/vmangelschots/reconciled-frontend` (public, built by the project's CI on push to main)
- **Storage:** `postgres-data` — 5Gi `truenas-iscsi`

## Routing

One Ingress: `/api`, `/admin`, `/static` → `reconciled-backend-svc:8000`, everything else → `reconciled-frontend-svc:80`.

## Deploy

```sh
cp secret.yaml.example secret.yaml   # fill in values
./deploy.sh
```

The backend's `migrate` init container runs migrations and creates the login user
from `BUDGET_APP_USERNAME`/`BUDGET_APP_PASSWORD` (first start only). To change the password:

```sh
kubectl -n reconciled exec deploy/reconciled-backend -- python manage.py changepassword <user>
```

## Bank sync

`bank-sync.yaml` is a CronJob that runs `python manage.py sync_banks` daily at
11:30 UTC. Keep `BANK_SYNC_TIMES` in `configmap.yaml` equal to its schedule:
the app only uses it to say when the next sync is. Run one now with:

```sh
kubectl -n reconciled create job --from=cronjob/bank-sync bank-sync-manual
kubectl -n reconciled logs -f job/bank-sync-manual
```

## Upgrade

Images use `:latest` with `imagePullPolicy: Always`:

```sh
kubectl -n reconciled rollout restart deploy/reconciled-backend deploy/reconciled-frontend
```

A changed `configmap.yaml` needs `kubectl apply -f configmap.yaml` first: pods
only read it when they start. The bank-sync job pulls the new image on its next run.

The backend uses the `Recreate` strategy so migrations never run while an old version is serving.

## Backup

```sh
kubectl -n reconciled exec deploy/postgres -- sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > reconciled-$(date +%F).sql
```

## Troubleshooting

```sh
kubectl -n reconciled logs deploy/reconciled-backend -c migrate
```
