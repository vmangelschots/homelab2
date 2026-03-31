# Plausible Analytics Setup Guide

This guide walks through the complete setup of Plausible Analytics for your workloads.

## Overview

Plausible Analytics is now configured for:
- **blog.mangelschots.org** (Ghost blog) - Priority
- **scrumpoker.mangelschots.org**
- **requests.mangelschots.org** (Jellyseerr)

Analytics dashboard: https://analytics.mangelschots.org

## Step 1: Deploy Plausible Analytics

### 1.1 Generate Secret Keys

Generate secure secrets for all components:

```bash
# Secret key for Plausible (64 bytes)
echo "SECRET_KEY_BASE: $(openssl rand -base64 64 | tr -d '\n')"

# PostgreSQL password (32 bytes, URL-safe)
echo "POSTGRES_PASSWORD: $(openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_')"

# ClickHouse password (32 bytes, URL-safe)
echo "CLICKHOUSE_PASSWORD: $(openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_')"
```

**Important**: Database passwords use URL-safe base64 encoding (replacing `+` with `-` and `/` with `_`) to prevent breaking database connection URLs.

### 1.2 Update Secret

Edit the secret file and replace ALL placeholders:

```bash
# Open the secret file
nano argo/plausible/secret.yaml
```

Replace these three values:
- `CHANGE_ME_GENERATE_A_RANDOM_SECRET_KEY_BASE_WITH_OPENSSL`
- `CHANGE_ME_GENERATE_POSTGRES_PASSWORD`
- `CHANGE_ME_GENERATE_CLICKHOUSE_PASSWORD`

Or create the secret directly:
```bash
kubectl create secret generic plausible-secret -n plausible \
  --from-literal=SECRET_KEY_BASE="your-64-byte-key-here" \
  --from-literal=POSTGRES_PASSWORD="your-postgres-password-here" \
  --from-literal=CLICKHOUSE_PASSWORD="your-clickhouse-password-here" \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 1.3 Deploy Plausible

```bash
# Deploy all Plausible components
kubectl apply -f argo/plausible/namespace.yaml
kubectl apply -f argo/plausible/pvc.yaml
kubectl apply -f argo/plausible/configmap.yaml
kubectl apply -f argo/plausible/secret.yaml
kubectl apply -f argo/plausible/postgres.yaml
kubectl apply -f argo/plausible/clickhouse.yaml
kubectl apply -f argo/plausible/plausible.yaml
```

Or if using ArgoCD, create an application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: plausible
  namespace: argocd
spec:
  project: default
  source:
    repoURL: <your-repo-url>
    targetRevision: main
    path: argo/plausible
  destination:
    server: https://kubernetes.default.svc
    namespace: plausible
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 1.4 Wait for Deployment

```bash
# Watch the deployment
kubectl get pods -n plausible -w

# Check logs
kubectl logs -n plausible deployment/plausible-postgres
kubectl logs -n plausible deployment/plausible-clickhouse
kubectl logs -n plausible deployment/plausible
```

Expected order:
1. PostgreSQL starts first
2. ClickHouse starts
3. Plausible init container runs migrations
4. Plausible main container starts

## Step 2: Create Admin Account

Once Plausible is running, create your admin account:

```bash
kubectl exec -it -n plausible deployment/plausible -- /bin/sh

# Inside the container, run:
/entrypoint.sh db seed --email=admin@mangelschots.org --name="Admin" --password="ChangeMe123!"

# Exit the container
exit
```

## Step 3: Configure Plausible Sites

1. Visit https://analytics.mangelschots.org
2. Login with your credentials
3. Click **"Add a website"**
4. Add each site:
   - Domain: `blog.mangelschots.org`
   - Timezone: `Europe/Brussels`
   - Click **"Add site"**
   
5. Repeat for:
   - `scrumpoker.mangelschots.org`
   - `requests.mangelschots.org`

## Step 4: Enable Tracking for Each Service

### 4.1 Ghost Blog (blog.mangelschots.org)

**Method: Code Injection in Ghost Admin**

1. Login to Ghost Admin: https://blog.mangelschots.org/ghost
2. Go to **Settings** → **Code Injection**
3. In **Site Header**, add:

```html
<script defer data-domain="blog.mangelschots.org" src="https://analytics.mangelschots.org/js/script.js"></script>
```

4. Click **Save**

**Verification:**
- Visit your blog
- Check browser DevTools → Network tab
- Look for request to `analytics.mangelschots.org/js/script.js`

See `argo/ghost/ANALYTICS.md` for advanced tracking options.

### 4.2 Scrumpoker (scrumpoker.mangelschots.org)

**Method: Nginx Sidecar with Script Injection**

Deploy the analytics-enabled version:

```bash
# Backup original
cp argo/scrumpoker/scrumpoker.yaml argo/scrumpoker/scrumpoker-original.yaml

# Deploy with analytics
kubectl apply -f argo/scrumpoker/scrumpoker-with-analytics.yaml
```

Or if you prefer to keep the original, manually rename:
```bash
mv argo/scrumpoker/scrumpoker.yaml argo/scrumpoker/scrumpoker-original.yaml
mv argo/scrumpoker/scrumpoker-with-analytics.yaml argo/scrumpoker/scrumpoker.yaml
kubectl apply -f argo/scrumpoker/scrumpoker.yaml
```

**Verification:**
```bash
# Check deployment
kubectl get pods -n scrumpoker
kubectl logs -n scrumpoker deployment/scrumpoker -c nginx

# Test in browser
curl -s https://scrumpoker.mangelschots.org | grep "analytics.mangelschots.org"
```

See `argo/scrumpoker/ANALYTICS.md` for details.

### 4.3 Jellyseerr (requests.mangelschots.org)

**Method: Nginx Sidecar with Script Injection**

Deploy the analytics-enabled version:

```bash
# Backup original
cp argo/jellyseer/deployment.yaml argo/jellyseer/deployment-original.yaml

# Deploy with analytics
kubectl apply -f argo/jellyseer/deployment-with-analytics.yaml
```

Or replace the file:
```bash
mv argo/jellyseer/deployment.yaml argo/jellyseer/deployment-original.yaml
mv argo/jellyseer/deployment-with-analytics.yaml argo/jellyseer/deployment.yaml
kubectl apply -f argo/jellyseer/deployment.yaml
```

**Verification:**
```bash
# Check deployment
kubectl get pods -n jellyseerr
kubectl logs -n jellyseerr deployment/jellyseerr -c nginx

# Test in browser
curl -s https://requests.mangelschots.org | grep "analytics.mangelschots.org"
```

See `argo/jellyseer/ANALYTICS.md` for details.

## Step 5: Verify Analytics Collection

### Real-time Dashboard

1. Visit https://analytics.mangelschots.org
2. Select a site from the dropdown
3. Open the actual site in another tab
4. Watch the real-time visitor count increase

### Check Each Site

For each service:
1. Visit the site
2. Open browser DevTools (F12)
3. Go to Network tab
4. Look for `script.js` from `analytics.mangelschots.org`
5. Check the Console for any errors

## Step 6: Configure Goals (Optional)

### Custom Events for Ghost

Add custom event tracking for important actions:

```javascript
// Newsletter signup
plausible('Newsletter Signup');

// Download tracking
plausible('File Download', {props: {file: 'whitepaper.pdf'}});

// Outbound links
plausible('Outbound Link: Click', {props: {url: 'https://example.com'}});
```

Add these in Ghost Admin → Settings → Code Injection → Site Footer

Then configure goals in Plausible:
1. Go to site settings
2. Click **Goals**
3. Add custom event goals for tracking

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Plausible Stack                      │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  PostgreSQL  │  │  ClickHouse  │  │  Plausible   │ │
│  │   (config)   │  │   (events)   │  │    (app)     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                         │
│  Storage: NFS-retain (persistent)                      │
└─────────────────────────────────────────────────────────┘
                            ▲
                            │ Tracking Data
                            │
                ┌───────────┴───────────┐
                │                       │
        ┌───────┴────────┐    ┌────────┴────────┐
        │  Ghost Blog    │    │  Scrumpoker &   │
        │  (via Ghost    │    │  Jellyseerr     │
        │  Code Inject)  │    │  (nginx sidecar)│
        └────────────────┘    └─────────────────┘
```

## Storage Requirements

- **PostgreSQL**: 10Gi (user accounts, site configs)
- **ClickHouse Data**: 20Gi (event storage)
- **ClickHouse Logs**: 5Gi (query logs)
- **Total**: ~35Gi
- **Storage Class**: truenas-iscsi (iSCSI block storage with Retain policy)

**Important**: PostgreSQL uses a subdirectory (`/var/lib/postgresql/data/pgdata`) to avoid the iSCSI root volume limitation.

Growth estimate:
- Small blog: ~10MB/month
- Medium traffic: ~100MB/month
- High traffic: ~1GB/month

Adjust PVC sizes as needed.

## Email Reports (Optional)

To enable email reports, edit the secret:

```bash
kubectl edit secret plausible-secret -n plausible
```

Add SMTP configuration:

```yaml
stringData:
  SECRET_KEY_BASE: "your-secret-key"
  SMTP_HOST_ADDR: "smtp.example.com"
  SMTP_HOST_PORT: "587"
  SMTP_USER_NAME: "user@example.com"
  SMTP_USER_PWD: "password"
  MAILER_EMAIL: "plausible@mangelschots.org"
```

Then restart Plausible:

```bash
kubectl rollout restart deployment/plausible -n plausible
```

## Backup Strategy

### PostgreSQL Database

Contains user accounts and site configurations:

```bash
# Create backup
kubectl exec -n plausible deployment/plausible-postgres -- \
  pg_dump -U plausible plausible | gzip > plausible-backup-$(date +%Y%m%d).sql.gz

# Restore backup
gunzip -c plausible-backup-20240101.sql.gz | \
  kubectl exec -i -n plausible deployment/plausible-postgres -- \
  psql -U plausible plausible
```

### ClickHouse Data

Event data is less critical (can be rebuilt) but to backup:

```bash
# List tables
kubectl exec -n plausible deployment/plausible-clickhouse -- \
  clickhouse-client --query "SHOW TABLES FROM plausible"

# Backup specific table
kubectl exec -n plausible deployment/plausible-clickhouse -- \
  clickhouse-client --query "SELECT * FROM plausible.events FORMAT CSVWithNames" | \
  gzip > events-backup-$(date +%Y%m%d).csv.gz
```

## Monitoring

### Health Checks

```bash
# Check Plausible health
curl https://analytics.mangelschots.org/api/health

# Check PostgreSQL
kubectl exec -n plausible deployment/plausible-postgres -- pg_isready -U plausible

# Check ClickHouse
kubectl exec -n plausible deployment/plausible-clickhouse -- \
  wget -q -O- http://localhost:8123/ping
```

### Resource Usage

```bash
# CPU and Memory
kubectl top pods -n plausible

# Storage
kubectl get pvc -n plausible
```

## Troubleshooting

### Plausible won't start

Check initialization logs:
```bash
kubectl logs -n plausible deployment/plausible -c plausible-init
```

Common issues:
- Database connection failed: Check PostgreSQL is running
- Migration failed: Check ClickHouse is running
- Secret key missing: Verify secret.yaml

### No data appearing

1. Check script is loading:
   - Open DevTools → Network
   - Look for `script.js`
   - Status should be 200

2. Check Plausible logs:
   ```bash
   kubectl logs -n plausible deployment/plausible
   ```

3. Verify site is configured:
   - Login to Plausible
   - Check site list
   - Domain must match exactly

### Performance issues

If ClickHouse is slow:
```bash
# Check ClickHouse memory
kubectl top pod -n plausible -l app=plausible-clickhouse

# Increase resources if needed
kubectl edit deployment plausible-clickhouse -n plausible
```

### Certificate issues

If TLS certificate fails:
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate
kubectl get certificate -n plausible
kubectl describe certificate plausible-tls -n plausible
```

## Security Considerations

1. **Registration disabled**: Set to `invite_only` by default
2. **HTTPS only**: All traffic encrypted via Traefik
3. **No cookies**: Plausible doesn't use cookies
4. **Privacy-first**: No personal data collected
5. **GDPR compliant**: Doesn't require cookie banners

### Creating New Users

```bash
# Invite a new user via CLI
kubectl exec -it -n plausible deployment/plausible -- /bin/sh
/entrypoint.sh db seed --email=newuser@example.com --name="New User" --password="SecurePass123!"
```

Or enable registration temporarily:
```bash
kubectl edit configmap plausible-config -n plausible
# Change DISABLE_REGISTRATION to "false"
kubectl rollout restart deployment/plausible -n plausible
```

## Maintenance

### Updating Plausible

```bash
# Update image tag in plausible.yaml
# Change from: plausible/analytics:v2.1
# To:          plausible/analytics:v2.2

kubectl apply -f argo/plausible/plausible.yaml

# Watch rollout
kubectl rollout status deployment/plausible -n plausible
```

### Database Maintenance

```bash
# PostgreSQL vacuum
kubectl exec -n plausible deployment/plausible-postgres -- \
  psql -U plausible -c "VACUUM ANALYZE;"

# ClickHouse optimize
kubectl exec -n plausible deployment/plausible-clickhouse -- \
  clickhouse-client --query "OPTIMIZE TABLE plausible.events FINAL;"
```

## Support and Documentation

- **Plausible Docs**: https://plausible.io/docs
- **Self-hosting Guide**: https://plausible.io/docs/self-hosting
- **API Documentation**: https://plausible.io/docs/stats-api
- **Community Forum**: https://github.com/plausible/analytics/discussions

## Next Steps

1. ✅ Deploy Plausible Analytics
2. ✅ Create admin account
3. ✅ Add sites to Plausible
4. ✅ Enable tracking on Ghost
5. ✅ Enable tracking on Scrumpoker
6. ✅ Enable tracking on Jellyseerr
7. 🔄 Monitor analytics data collection
8. 📊 Set up email reports (optional)
9. 🎯 Configure custom goals (optional)
10. 📈 Create Grafana dashboard (optional)

Enjoy your privacy-friendly analytics! 🎉
