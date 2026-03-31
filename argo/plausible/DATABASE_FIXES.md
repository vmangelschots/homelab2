# Database Connection Fixes

## Issue 1: URL-Unsafe Characters in Passwords

### Problem
Base64-encoded passwords can contain `/` and `+` characters which break URL parsing in connection strings like:
```
postgres://plausible:rNdYQ+QlBopU0Dkmu/ZgQRhPiFeq@host:5432/db
                           ^      ^
                      These break the URL!
```

### Solution
Use URL-safe base64 encoding by replacing `+` with `-` and `/` with `_`:

```bash
# Generate URL-safe passwords
openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_'
```

### Updated Passwords
```yaml
# Old (unsafe - contains + and /)
POSTGRES_PASSWORD: "rNdYQ+QlBopU0Dkmu2ZgQRhPiFeq1xmSGz+LbQrowWY="
CLICKHOUSE_PASSWORD: "OnpNOmwCAVhU//fGHG+pOdsYAyNZofrRdtSngQrk498="

# New (safe - no + or /)
POSTGRES_PASSWORD: "s0JzJrTv0rPtoNzlv3Bm4QNtwcbn2Yma2BkJ8APZavg="
CLICKHOUSE_PASSWORD: "j1W74tku8q7nwTAq6AbZ7xlfKHkisVDdaVdLeuf0nRY="
```

## Issue 2: Incomplete DNS Names

### Problem
Using short service names like `plausible-postgres` instead of fully-qualified domain names (FQDN) can cause DNS resolution issues, especially:
- Cross-namespace communication
- DNS caching problems
- Service mesh compatibility
- Explicit cluster locality

### Solution
Use full Kubernetes DNS format:
```
<service-name>.<namespace>.svc.cluster.local
```

### Updated Connection Strings

**Before:**
```bash
export DATABASE_URL="postgres://plausible:${POSTGRES_PASSWORD}@plausible-postgres:5432/plausible"
export CLICKHOUSE_DATABASE_URL="http://plausible:${CLICKHOUSE_PASSWORD}@plausible-clickhouse:8123/plausible"
```

**After:**
```bash
export DATABASE_URL="postgres://plausible:${POSTGRES_PASSWORD}@plausible-postgres.plausible.svc.cluster.local:5432/plausible"
export CLICKHOUSE_DATABASE_URL="http://plausible:${CLICKHOUSE_PASSWORD}@plausible-clickhouse.plausible.svc.cluster.local:8123/plausible"
```

## Kubernetes DNS Format Explanation

```
plausible-postgres.plausible.svc.cluster.local
       |               |        |       |
   service name    namespace  service  cluster domain
```

- **service name**: `plausible-postgres` or `plausible-clickhouse`
- **namespace**: `plausible`
- **svc**: Indicates this is a service
- **cluster.local**: Default cluster domain

## Benefits of Full DNS Names

✅ **Explicit and clear** - No ambiguity about which service  
✅ **Cross-namespace** - Works even if services are in different namespaces  
✅ **DNS caching** - Better cache behavior  
✅ **Service mesh** - Required by some service mesh implementations  
✅ **Debugging** - Easier to trace DNS queries  
✅ **Best practice** - Recommended by Kubernetes documentation  

## Verification

### Test DNS Resolution

```bash
# From within the plausible pod
kubectl exec -n plausible deployment/plausible -- \
  nslookup plausible-postgres.plausible.svc.cluster.local

# Should return the service ClusterIP
```

### Test Database Connection

```bash
# Test PostgreSQL connection
kubectl exec -n plausible deployment/plausible -- \
  /bin/sh -c 'psql "$DATABASE_URL" -c "SELECT version();"'

# Test ClickHouse connection
kubectl exec -n plausible deployment/plausible -- \
  /bin/sh -c 'wget -qO- "${CLICKHOUSE_DATABASE_URL}/ping"'
```

### Check for URL Encoding Issues

```bash
# View the constructed DATABASE_URL (password will be visible!)
kubectl exec -n plausible deployment/plausible -- \
  /bin/sh -c 'echo $DATABASE_URL'

# Should show properly formatted URL without broken characters
```

## Additional Fixes Applied

### Image Version Consistency
Both initContainer and main container now use the same version:
```yaml
image: plausible/analytics:v2.1
```

Avoid using `:latest` in production as it can cause:
- Inconsistent deployments
- Rollback difficulties  
- Unpredictable behavior

## Summary of Changes

### secret.yaml
- ✅ Regenerated passwords with URL-safe base64 encoding
- ✅ No `+` or `/` characters in passwords
- ✅ Passwords remain cryptographically strong (32 bytes)

### plausible.yaml
- ✅ Updated to use full Kubernetes DNS names
- ✅ Fixed both initContainer and main container
- ✅ Consistent image version (v2.1)

### Testing
```bash
# Validate YAML
kubectl --dry-run=client apply -f argo/plausible/

# Check for password issues
grep -E '\+|/' argo/plausible/secret.yaml
# Should return nothing

# Check DNS names
grep "svc.cluster.local" argo/plausible/plausible.yaml
# Should return 4 matches (2 in initContainer, 2 in main container)
```

## Generating New URL-Safe Passwords

If you need to regenerate passwords in the future:

```bash
# Generate all secrets with URL-safe base64
echo "SECRET_KEY_BASE: $(openssl rand -base64 64 | tr -d '\n')"
echo "POSTGRES_PASSWORD: $(openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_')"
echo "CLICKHOUSE_PASSWORD: $(openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_')"
```

**Note**: The SECRET_KEY_BASE doesn't need URL-safe encoding as it's not used in URLs.

## Ready to Deploy

All issues fixed! Deploy with:

```bash
./argo/plausible/deploy.sh
```

Or manually:
```bash
kubectl apply -f argo/plausible/secret.yaml
kubectl apply -f argo/plausible/
```
