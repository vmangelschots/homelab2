# Ghostfolio

Open Source Wealth Management Software for tracking stocks, ETFs, and cryptocurrencies.

## Overview

Ghostfolio is a modern web application that empowers you to keep track of your investment portfolio and make data-driven decisions. Built with Angular, NestJS, Prisma, and PostgreSQL.

**Official Website:** https://ghostfol.io  
**GitHub:** https://github.com/ghostfolio/ghostfolio

## Features

- Multi account management
- Portfolio performance tracking (Today, WTD, MTD, YTD, 1Y, 5Y, Max)
- Various charts and visualizations
- Static analysis to identify portfolio risks
- Import and export transactions
- Dark Mode and Zen Mode
- Progressive Web App (PWA) with mobile-first design

## Architecture

This deployment consists of three main components:

- **Ghostfolio Application** (ghostfolio/ghostfolio:latest)
- **PostgreSQL 16** (database)
- **Redis 7** (caching layer)

## Prerequisites

- Kubernetes cluster with kubectl access
- Traefik ingress controller
- cert-manager with Let's Encrypt DNS-01 issuer configured
- Storage class: `truenas-iscsi`

## Installation

### Quick Deploy

Use the provided deployment script:

```bash
cd ghostfolio
./deploy.sh
```

### Manual Deploy

1. **Create namespace:**
   ```bash
   kubectl apply -f namespace.yaml
   ```

2. **Create secrets:**
   ```bash
   # The secret.yaml file is already created with random values
   kubectl apply -f secret.yaml
   ```
   
   If you need to regenerate secrets, copy from the example:
   ```bash
   cp secret.yaml.example secret.yaml
   # Edit secret.yaml and replace placeholders with secure random values
   openssl rand -base64 32  # For ACCESS_TOKEN_SALT
   openssl rand -base64 32  # For JWT_SECRET_KEY
   openssl rand -base64 24  # For POSTGRES_PASSWORD
   openssl rand -base64 24  # For REDIS_PASSWORD
   ```

3. **Create persistent storage:**
   ```bash
   kubectl apply -f pvc.yaml
   ```

4. **Deploy PostgreSQL:**
   ```bash
   kubectl apply -f postgres.yaml
   kubectl wait --for=condition=ready pod -l app=postgres -n ghostfolio --timeout=300s
   ```

5. **Deploy Redis:**
   ```bash
   kubectl apply -f redis.yaml
   kubectl wait --for=condition=ready pod -l app=redis -n ghostfolio --timeout=120s
   ```

6. **Deploy Ghostfolio:**
   ```bash
   kubectl apply -f ghostfolio.yaml
   kubectl wait --for=condition=ready pod -l app=ghostfolio -n ghostfolio --timeout=300s
   ```

## Access

Once deployed, access Ghostfolio at:

**https://ghostfolio.mangelschots.org**

## First-Time Setup

1. Navigate to https://ghostfolio.mangelschots.org
2. Click **"Get Started"** to create your first user account
3. The first user automatically receives the `ADMIN` role
4. Start adding your investment accounts and transactions

## Configuration

### Environment Variables

The following environment variables are configured:

| Variable | Value | Description |
|----------|-------|-------------|
| `DATABASE_URL` | Auto-configured | PostgreSQL connection string |
| `REDIS_HOST` | redis-svc | Redis service hostname |
| `REDIS_PORT` | 6379 | Redis service port |
| `REDIS_DB` | 0 | Redis database index |
| `ACCESS_TOKEN_SALT` | From secret | Salt for access tokens |
| `JWT_SECRET_KEY` | From secret | JWT signing key |
| `BASE_CURRENCY` | EUR | Default base currency for the application |
| `ENABLE_FEATURE_AUTH_TOKEN` | true | Enable security token authentication |
| `HOST` | 0.0.0.0 | Application host |
| `PORT` | 3333 | Application port |

### Resource Limits

**Ghostfolio:**
- Requests: 100m CPU, 256Mi memory
- Limits: 1000m CPU, 1Gi memory

**PostgreSQL:**
- Requests: 100m CPU, 256Mi memory
- Limits: 1000m CPU, 2Gi memory

**Redis:**
- Requests: 50m CPU, 128Mi memory
- Limits: 500m CPU, 512Mi memory

### Storage

- **PostgreSQL Data:** 10Gi on `truenas-iscsi` storage class
- **Redis:** No persistent storage (cache only)

## Management

### View deployment status

```bash
kubectl get all -n ghostfolio
```

### View logs

```bash
# Ghostfolio application
kubectl logs -f deployment/ghostfolio -n ghostfolio

# PostgreSQL
kubectl logs -f deployment/postgres -n ghostfolio

# Redis
kubectl logs -f deployment/redis -n ghostfolio
```

### Check ingress

```bash
kubectl get ingress -n ghostfolio
kubectl describe ingress ghostfolio -n ghostfolio
```

### Access database

```bash
# Port-forward to PostgreSQL
kubectl port-forward -n ghostfolio svc/postgres-svc 5432:5432

# Connect using psql (in another terminal)
PGPASSWORD=<your-password> psql -h localhost -U ghostfolio -d ghostfolio
```

### Restart services

```bash
# Restart Ghostfolio
kubectl rollout restart deployment/ghostfolio -n ghostfolio

# Restart PostgreSQL
kubectl rollout restart deployment/postgres -n ghostfolio

# Restart Redis
kubectl rollout restart deployment/redis -n ghostfolio
```

## Backup and Restore

### Backup PostgreSQL Database

```bash
# Create backup
kubectl exec -n ghostfolio deployment/postgres -- pg_dump -U ghostfolio ghostfolio > ghostfolio-backup-$(date +%Y%m%d).sql
```

### Restore PostgreSQL Database

```bash
# Restore from backup
kubectl exec -i -n ghostfolio deployment/postgres -- psql -U ghostfolio -d ghostfolio < ghostfolio-backup-20260305.sql
```

## API Access

Ghostfolio provides a public API for automation and integrations.

### Get Bearer Token

```bash
# Get security token from your account settings in the web UI
# Then exchange it for a bearer token:
curl -X POST https://ghostfolio.mangelschots.org/api/v1/auth/anonymous \
  -H "Content-Type: application/json" \
  -d '{"accessToken": "YOUR_SECURITY_TOKEN"}'
```

### Health Check

```bash
curl https://ghostfolio.mangelschots.org/api/v1/health
```

### Import Activities

```bash
curl -X POST https://ghostfolio.mangelschots.org/api/v1/import \
  -H "Authorization: Bearer YOUR_BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "activities": [{
      "currency": "USD",
      "dataSource": "YAHOO",
      "date": "2026-03-05T00:00:00.000Z",
      "fee": 0,
      "quantity": 10,
      "symbol": "AAPL",
      "type": "BUY",
      "unitPrice": 150.00
    }]
  }'
```

## Upgrading

To upgrade to a new version:

1. **Update the image tag** in `ghostfolio.yaml` (currently set to `latest`)
2. **Apply the changes:**
   ```bash
   kubectl apply -f ghostfolio.yaml
   ```
3. **Wait for rollout:**
   ```bash
   kubectl rollout status deployment/ghostfolio -n ghostfolio
   ```

The Ghostfolio container automatically applies database migrations on startup.

## Troubleshooting

### Ghostfolio pod not starting

Check logs:
```bash
kubectl logs -f deployment/ghostfolio -n ghostfolio
```

Common issues:
- Database connection errors: Verify PostgreSQL is running and credentials are correct
- Redis connection errors: Verify Redis is running and password is correct
- Migration errors: Check database logs and ensure database is accessible

### Database connection issues

Verify PostgreSQL is running:
```bash
kubectl get pods -n ghostfolio -l app=postgres
kubectl logs deployment/postgres -n ghostfolio
```

Test database connectivity:
```bash
kubectl exec -it deployment/postgres -n ghostfolio -- psql -U ghostfolio -d ghostfolio -c "SELECT 1;"
```

### Cannot access via ingress

Check ingress status:
```bash
kubectl describe ingress ghostfolio -n ghostfolio
```

Verify TLS certificate:
```bash
kubectl get certificate -n ghostfolio
kubectl describe certificate ghostfolio-tls -n ghostfolio
```

### Performance issues

Monitor resource usage:
```bash
kubectl top pods -n ghostfolio
```

Consider increasing resource limits in the respective YAML files.

## Uninstall

To completely remove Ghostfolio:

```bash
kubectl delete namespace ghostfolio
```

**Warning:** This will delete all data including your portfolio information. Make sure to backup first!

## Support

- **Official Documentation:** https://ghostfol.io
- **GitHub Issues:** https://github.com/ghostfolio/ghostfolio/issues
- **Community Slack:** https://join.slack.com/t/ghostfolio/shared_invite/zt-vsaan64h-F_I0fEo5M0P88lP9ibCxFg

## License

Ghostfolio is licensed under AGPLv3. See https://github.com/ghostfolio/ghostfolio for details.
