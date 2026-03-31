# Database Connection Configuration

## How Database Connections Work

Plausible requires two database connection URLs:
1. **DATABASE_URL** - PostgreSQL connection string
2. **CLICKHOUSE_DATABASE_URL** - ClickHouse connection string

## Implementation

### ConfigMap (plausible-config)

Contains only non-sensitive configuration:
```yaml
BASE_URL: "https://analytics.mangelschots.org"
PORT: "8000"
DISABLE_REGISTRATION: "invite_only"
```

### Secret (plausible-secret)

Contains all sensitive data:
- `SECRET_KEY_BASE` - Plausible encryption key
- `POSTGRES_PASSWORD` - PostgreSQL password
- `CLICKHOUSE_PASSWORD` - ClickHouse password

### Plausible Deployment

Database URLs are constructed dynamically in the container startup using shell variable expansion:

**InitContainer (for migrations):**
```yaml
command:
- /bin/sh
- -c
- |
  export DATABASE_URL="postgres://plausible:${POSTGRES_PASSWORD}@plausible-postgres:5432/plausible"
  export CLICKHOUSE_DATABASE_URL="http://plausible:${CLICKHOUSE_PASSWORD}@plausible-clickhouse:8123/plausible"
  sleep 10 && /entrypoint.sh db createdb && /entrypoint.sh db migrate
```

**Main Container:**
```yaml
command:
- /bin/sh
- -c
- |
  export DATABASE_URL="postgres://plausible:${POSTGRES_PASSWORD}@plausible-postgres:5432/plausible"
  export CLICKHOUSE_DATABASE_URL="http://plausible:${CLICKHOUSE_PASSWORD}@plausible-clickhouse:8123/plausible"
  /entrypoint.sh run
```

### Why This Approach?

1. **Security**: Passwords never appear in ConfigMaps or plain YAML values
2. **Flexibility**: Connection details constructed at runtime from secrets
3. **Shell expansion**: Uses `${POSTGRES_PASSWORD}` which shell properly expands
4. **Single source of truth**: Passwords only stored once in the secret

### Connection String Format

**PostgreSQL:**
```
postgres://USER:PASSWORD@HOST:PORT/DATABASE
postgres://plausible:${POSTGRES_PASSWORD}@plausible-postgres:5432/plausible
```

**ClickHouse:**
```
http://USER:PASSWORD@HOST:PORT/DATABASE
http://plausible:${CLICKHOUSE_PASSWORD}@plausible-clickhouse:8123/plausible
```

## Verification

After deployment, verify the connections work:

```bash
# Check if Plausible can connect to PostgreSQL
kubectl exec -n plausible deployment/plausible -- \
  /bin/sh -c 'psql $DATABASE_URL -c "SELECT version();"'

# Check if Plausible can connect to ClickHouse
kubectl exec -n plausible deployment/plausible -- \
  /bin/sh -c 'wget -qO- "${CLICKHOUSE_DATABASE_URL}/ping"'
```

## Troubleshooting

### Database connection errors

If you see connection errors in logs:

```bash
# Check Plausible logs
kubectl logs -n plausible deployment/plausible

# Common errors and solutions:
# - "password authentication failed" → Check POSTGRES_PASSWORD in secret
# - "could not connect to server" → Check database pods are running
# - "database does not exist" → Check initContainer completed successfully
```

### Verify environment variables

```bash
# Check what environment variables Plausible sees
kubectl exec -n plausible deployment/plausible -- env | grep -E "DATABASE_URL|CLICKHOUSE"

# Should NOT show passwords (they're in the constructed URL)
```

### Test database directly

```bash
# Test PostgreSQL from Plausible pod
kubectl exec -n plausible deployment/plausible -- \
  /bin/sh -c 'echo "SELECT 1" | psql $DATABASE_URL'

# Test ClickHouse from Plausible pod
kubectl exec -n plausible deployment/plausible -- \
  /bin/sh -c 'wget -qO- "$CLICKHOUSE_DATABASE_URL/ping"'
```

## Security Notes

✅ Passwords stored in Kubernetes secrets (not ConfigMaps)  
✅ Connection URLs constructed at runtime (not hardcoded)  
✅ Shell variable expansion happens inside container (secure)  
✅ No passwords in git repository (use generated secrets)  
✅ Secrets can be encrypted at rest (enable in Kubernetes)  

## Comparison with Previous Approach

### ❌ Old Approach (Insecure)
```yaml
# ConfigMap with hardcoded passwords
DATABASE_URL: "postgres://plausible:plausible@plausible-postgres:5432/plausible"
```

### ✅ New Approach (Secure)
```yaml
# Secret with passwords
POSTGRES_PASSWORD: "rNdYQ+QlBopU0Dkmu2ZgQRhPiFeq1xmSGz+LbQrowWY="

# Container command constructs URL at runtime
export DATABASE_URL="postgres://plausible:${POSTGRES_PASSWORD}@plausible-postgres:5432/plausible"
```

## Summary

- ✅ ConfigMap contains only non-sensitive configuration
- ✅ Secrets contain all passwords
- ✅ Database URLs constructed at runtime using shell expansion
- ✅ No hardcoded passwords anywhere
- ✅ Both initContainer and main container use same pattern
- ✅ Plausible receives fully-formed DATABASE_URL environment variable
