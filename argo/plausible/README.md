# Plausible Analytics

Privacy-friendly web analytics for mangelschots.org services.

## Services

- **URL**: https://analytics.mangelschots.org
- **Registration**: Invite-only (disabled by default)

## Architecture

- **Plausible**: Main analytics application (v2.1)
- **PostgreSQL 16**: User data and configuration storage
- **ClickHouse 24.3**: Event data and analytics storage

## Tracked Sites

- blog.mangelschots.org (Ghost blog)
- scrumpoker.mangelschots.org
- requests.mangelschots.org (Jellyseerr)
- movies.mangelschots.org (Jellyfin - optional)

## Initial Setup

1. Generate secure secrets:
   ```bash
   # Secret key for Plausible
   openssl rand -base64 64 | tr -d '\n'
   
   # PostgreSQL password (URL-safe: no + or / characters)
   openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_'
   
   # ClickHouse password (URL-safe: no + or / characters)
   openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_'
   ```
   
   **Important**: Database passwords use URL-safe encoding to avoid breaking connection strings.

2. Update `secret.yaml` with the generated keys:
   - Replace `CHANGE_ME_GENERATE_A_RANDOM_SECRET_KEY_BASE_WITH_OPENSSL` with the 64-byte key
   - Replace `CHANGE_ME_GENERATE_POSTGRES_PASSWORD` with the PostgreSQL password
   - Replace `CHANGE_ME_GENERATE_CLICKHOUSE_PASSWORD` with the ClickHouse password
   
   Or edit after deployment:
   ```bash
   kubectl edit secret plausible-secret -n plausible
   ```

3. Create your admin account:
   ```bash
   kubectl exec -it -n plausible deployment/plausible -- /bin/sh
   # Inside the container:
   /entrypoint.sh db seed --email=admin@mangelschots.org --name="Admin" --password="ChangeMe123!"
   exit
   ```

4. Login at https://analytics.mangelschots.org and add your sites:
   - blog.mangelschots.org
   - scrumpoker.mangelschots.org
   - requests.mangelschots.org

## Adding Tracking Scripts

### For Ghost (blog.mangelschots.org)

Add to Ghost Admin → Settings → Code Injection → Site Header:
```html
<script defer data-domain="blog.mangelschots.org" src="https://analytics.mangelschots.org/js/script.js"></script>
```

### For other services

Inject the tracking script into the HTML of each service.

## Storage

- PostgreSQL: 10Gi (user data, configuration)
- ClickHouse Data: 20Gi (event storage)
- ClickHouse Logs: 5Gi (query logs)
- Storage Class: truenas-iscsi (iSCSI block storage with Retain policy)

**Note**: PostgreSQL uses a subdirectory (`/var/lib/postgresql/data/pgdata`) to avoid the iSCSI root volume issue.

## Resources

- PostgreSQL: 256Mi-1Gi RAM, 100m-1000m CPU
- ClickHouse: 512Mi-2Gi RAM, 200m-2000m CPU
- Plausible: 256Mi-1Gi RAM, 100m-1000m CPU

## Monitoring

Plausible provides a health check endpoint at `/api/health`

## Backup

Important data is stored in PostgreSQL PVC: `plausible-postgres-data`

## Features

- Real-time dashboard
- Privacy-friendly (no cookies, GDPR compliant)
- Lightweight tracking script (<1KB)
- Page views, visitors, bounce rate
- Top pages, referrers, countries
- Goal conversions
- Custom events
- Email reports (configure SMTP in secret.yaml)

## Configuration

Edit environment variables in:
- `configmap.yaml` - Non-sensitive configuration
- `secret.yaml` - Sensitive data (secret key, SMTP credentials)

## Troubleshooting

Check logs:
```bash
kubectl logs -n plausible deployment/plausible
kubectl logs -n plausible deployment/plausible-postgres
kubectl logs -n plausible deployment/plausible-clickhouse
```

## References

- [Plausible Documentation](https://plausible.io/docs)
- [Self-hosting Guide](https://plausible.io/docs/self-hosting)
