# Security Configuration Notice

## ⚠️ IMPORTANT: Set Secure Passwords Before Deployment

The Plausible Analytics deployment requires **three secure secrets** to be configured before deployment:

### Required Secrets

1. **SECRET_KEY_BASE** (64 bytes)
   - Used by Plausible for session encryption and security
   - Generate: `openssl rand -base64 64 | tr -d '\n'`

2. **POSTGRES_PASSWORD** (32 bytes)
   - PostgreSQL database password
   - Generate: `openssl rand -base64 32`

3. **CLICKHOUSE_PASSWORD** (32 bytes)
   - ClickHouse database password
   - Generate: `openssl rand -base64 32`

### Configuration Steps

1. **Generate all secrets at once:**
   ```bash
   echo "Copy these values to argo/plausible/secret.yaml:"
   echo ""
   echo "SECRET_KEY_BASE: $(openssl rand -base64 64 | tr -d '\n')"
   echo "POSTGRES_PASSWORD: $(openssl rand -base64 32)"
   echo "CLICKHOUSE_PASSWORD: $(openssl rand -base64 32)"
   ```

2. **Edit the secret file:**
   ```bash
   nano argo/plausible/secret.yaml
   ```

3. **Replace these placeholders:**
   - `CHANGE_ME_GENERATE_A_RANDOM_SECRET_KEY_BASE_WITH_OPENSSL`
   - `CHANGE_ME_GENERATE_POSTGRES_PASSWORD`
   - `CHANGE_ME_GENERATE_CLICKHOUSE_PASSWORD`

### Why This Matters

- **PostgreSQL** and **ClickHouse** previously had hardcoded passwords ("plausible")
- This has been **fixed** to use Kubernetes secrets with environment variable injection
- All database connections now use passwords from the secret
- **You MUST set these before deploying** or the deployment will fail with clear error messages

### Verification

The deployment script (`deploy.sh`) will check for placeholder values and refuse to deploy if secrets are not configured.

### Security Best Practices

✅ **DO:**
- Generate strong random passwords (use the commands above)
- Store the secrets securely (password manager, vault)
- Use different passwords for each component
- Rotate secrets periodically

❌ **DON'T:**
- Use simple passwords like "password" or "plausible"
- Reuse passwords across environments
- Commit real secrets to git
- Share secrets in plaintext

### Git Ignore

If you want to keep secrets out of git entirely, add to `.gitignore`:
```
argo/plausible/secret.yaml
```

Then create the secret directly in Kubernetes:
```bash
kubectl create namespace plausible

kubectl create secret generic plausible-secret -n plausible \
  --from-literal=SECRET_KEY_BASE="your-secret-key-here" \
  --from-literal=POSTGRES_PASSWORD="your-postgres-password" \
  --from-literal=CLICKHOUSE_PASSWORD="your-clickhouse-password"
```

### Current Implementation

The passwords are now properly secured:

**PostgreSQL** (`argo/plausible/postgres.yaml`):
```yaml
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: plausible-secret
      key: POSTGRES_PASSWORD
```

**ClickHouse** (`argo/plausible/clickhouse.yaml`):
```yaml
- name: CLICKHOUSE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: plausible-secret
      key: CLICKHOUSE_PASSWORD
```

**Plausible** (`argo/plausible/plausible.yaml`):
```yaml
- name: DATABASE_URL
  value: "postgres://plausible:$(POSTGRES_PASSWORD)@plausible-postgres:5432/plausible"
- name: CLICKHOUSE_DATABASE_URL
  value: "http://plausible:$(CLICKHOUSE_PASSWORD)@plausible-clickhouse:8123/plausible"
```

## Summary

✅ All hardcoded passwords have been removed
✅ Database passwords are now stored in Kubernetes secrets
✅ Environment variables properly reference secrets
✅ Deployment script validates secrets before deployment
✅ Documentation updated with security best practices

**Before deploying, generate and configure all three secrets!**
