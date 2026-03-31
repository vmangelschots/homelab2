# Kubernetes Workload Standards

This document defines the standards and patterns for creating new workloads in this Kubernetes cluster.

## Repository Structure

This is a **Kubernetes-based infrastructure repository** using a **GitOps approach** with direct `kubectl apply`. Each workload gets its own directory at the root level of `/root/cluster/argo/`.

## Directory Structure

### Simple Single-Container Workload
```
workload-name/
├── namespace.yaml
├── pvc.yaml (if persistent storage needed)
├── deployment.yaml (or workload-name.yaml)
└── README.md
```

### Complex Multi-Service Workload
```
workload-name/
├── namespace.yaml
├── pvc.yaml
├── secret.yaml (gitignored)
├── secret.yaml.example
├── configmap.yaml (optional)
├── database.yaml (e.g., postgres.yaml, mysql.yaml)
├── cache.yaml (e.g., redis.yaml)
├── workload-name.yaml (main application + service + ingress)
├── deploy.sh (optional automation script)
└── README.md
```

## File Naming Conventions

- **Namespace:** `namespace.yaml`
- **Storage:** `pvc.yaml`
- **Secrets:** `secret.yaml` (gitignored) + `secret.yaml.example` (template)
- **Configuration:** `configmap.yaml`
- **Database:** `postgres.yaml`, `mysql.yaml`, `clickhouse.yaml`, etc.
- **Cache:** `redis.yaml`
- **Main Application:** `<workload-name>.yaml` or `deployment.yaml`
- **Documentation:** `README.md`
- **Deployment Script:** `deploy.sh` (executable)

## Standard Kubernetes Manifest Patterns

### 1. Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: workload-name
  labels:
    app.kubernetes.io/name: workload-name
    app.kubernetes.io/instance: workload-name
```

**Standards:**
- One namespace per workload
- Use consistent labels: `app.kubernetes.io/name` and `app.kubernetes.io/instance`

### 2. Persistent Volume Claims

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: workload-name
spec:
  accessModes:
    - ReadWriteOnce  # or ReadWriteMany for NFS
  storageClassName: truenas-iscsi  # or nfs-retain, nfs-static
  resources:
    requests:
      storage: 10Gi
```

**Storage Class Selection:**
- **`truenas-iscsi`** - iSCSI block storage, best for databases (RECOMMENDED for databases)
- **`nfs-retain`** - NFS with retain policy, good for general application data
- **`nfs-static`** - Static NFS volumes

**Access Modes:**
- **ReadWriteOnce (RWO)** - Single node read-write (use for databases, iSCSI)
- **ReadWriteMany (RWM)** - Multiple nodes read-write (use for NFS shared storage)

### 3. Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: workload-name
type: Opaque
stringData:
  password: "CHANGE_ME"
  api-key: "CHANGE_ME"
```

**Standards:**
- Always create both `secret.yaml` (gitignored) and `secret.yaml.example` (template)
- Use `stringData` for plaintext secrets (auto-encoded to base64)
- Generate secure random values: `openssl rand -base64 32`
- Never commit actual secrets to git

### 4. ConfigMaps

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: workload-name
data:
  config-key: "value"
  another-key: "another-value"
```

**Standards:**
- Use ConfigMaps for non-sensitive configuration
- Use Secrets for sensitive data

### 5. Deployments

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-name
  namespace: workload-name
  labels:
    app.kubernetes.io/name: app-name
    app.kubernetes.io/instance: app-name
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-name
  template:
    metadata:
      labels:
        app: app-name
    spec:
      # Optional: Init containers for setup tasks
      initContainers:
        - name: wait-for-database
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              until nc -z database-svc 5432; do
                echo "Waiting for database to be ready..."
                sleep 2
              done
              echo "Database is ready!"
      
      containers:
        - name: app-name
          image: image:tag  # Use specific tags, avoid :latest in production
          imagePullPolicy: IfNotPresent  # or Always for :latest
          
          # For complex environment variable construction, use shell wrapper
          command:
            - /bin/sh
            - -c
            - |
              export DATABASE_URL="postgresql://user:${DB_PASSWORD}@db-svc:5432/dbname"
              exec /path/to/entrypoint.sh
          
          ports:
            - containerPort: 8080
              name: http
          
          # Environment variables
          env:
            - name: SIMPLE_VAR
              value: "value"
            - name: SECRET_VAR
              valueFrom:
                secretKeyRef:
                  name: app-secret
                  key: secret-key
            - name: CONFIG_VAR
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: config-key
          
          # Or use envFrom for bulk loading
          envFrom:
            - configMapRef:
                name: app-config
            - secretRef:
                name: app-secret
          
          # Volume mounts
          volumeMounts:
            - name: data
              mountPath: /app/data
          
          # Health checks (IMPORTANT - always include)
          readinessProbe:
            httpGet:
              path: /health  # or /api/health, /api/v1/health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 5
          
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
          
          # Resource limits (IMPORTANT - always set)
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 1000m
              memory: 1Gi
      
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: app-data
```

**Resource Sizing Guidelines:**
- **Small apps:** 100m CPU / 256Mi RAM requests, 1000m CPU / 1Gi RAM limits
- **Databases:** 100m CPU / 256Mi RAM requests, 1000m CPU / 2Gi RAM limits
- **Caching (Redis):** 50m CPU / 128Mi RAM requests, 500m CPU / 512Mi RAM limits

**Important Notes:**
- Always include health probes (readiness and liveness)
- Always set resource requests and limits
- Use init containers to wait for dependencies
- For DATABASE_URL construction, use shell wrapper with `export` and `exec`

### 6. Services

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-svc
  namespace: workload-name
  labels:
    app.kubernetes.io/name: app-name
spec:
  type: ClusterIP
  selector:
    app: app-name
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 8080
```

**Standards:**
- Service name pattern: `<app>-svc`
- Always use ClusterIP (not LoadBalancer or NodePort)
- Use named ports
- Match selector to deployment labels

### 7. Ingress (Traefik with TLS)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-name
  namespace: workload-name
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-dns01
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    # Optional: for internal-only access
    # traefik.ingress.kubernetes.io/router.middlewares: default-internal-whitelist@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - app.mangelschots.org
      secretName: app-tls
  rules:
    - host: app.mangelschots.org
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-svc
                port:
                  number: 80
```

**Standards:**
- Domain pattern: `<app>.mangelschots.org`
- Always use TLS with Let's Encrypt DNS-01 challenge
- Use Traefik ingress class
- Secret name pattern: `<app>-tls`

### 8. PostgreSQL Database

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: workload-name
  labels:
    app.kubernetes.io/name: postgres
    app.kubernetes.io/instance: workload-postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5432
              name: postgres
          env:
            - name: POSTGRES_DB
              value: dbname
            - name: POSTGRES_USER
              value: username
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: app-secret
                  key: POSTGRES_PASSWORD
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
          readinessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - username
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - username
            initialDelaySeconds: 30
            periodSeconds: 10
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 1000m
              memory: 2Gi
      volumes:
        - name: postgres-data
          persistentVolumeClaim:
            claimName: postgres-data
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-svc
  namespace: workload-name
  labels:
    app.kubernetes.io/name: postgres
spec:
  type: ClusterIP
  selector:
    app: postgres
  ports:
    - name: postgres
      protocol: TCP
      port: 5432
      targetPort: 5432
```

**Connection String Pattern:**
```
postgresql://username:password@postgres-svc:5432/dbname?sslmode=prefer
```

### 9. Redis Cache

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: workload-name
  labels:
    app.kubernetes.io/name: redis
    app.kubernetes.io/instance: workload-redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: redis:7-alpine
          imagePullPolicy: IfNotPresent
          command:
            - redis-server
            - --requirepass
            - $(REDIS_PASSWORD)
          ports:
            - containerPort: 6379
              name: redis
          env:
            - name: REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: app-secret
                  key: REDIS_PASSWORD
          readinessProbe:
            exec:
              command:
                - redis-cli
                - --pass
                - $(REDIS_PASSWORD)
                - ping
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            exec:
              command:
                - redis-cli
                - --pass
                - $(REDIS_PASSWORD)
                - ping
            initialDelaySeconds: 15
            periodSeconds: 10
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: redis-svc
  namespace: workload-name
  labels:
    app.kubernetes.io/name: redis
spec:
  type: ClusterIP
  selector:
    app: redis
  ports:
    - name: redis
      protocol: TCP
      port: 6379
      targetPort: 6379
```

**Note:** Redis typically doesn't need persistent storage for caching use cases.

## Deployment Script Template

```bash
#!/bin/bash

set -e

echo "========================================="
echo "  Deploying <WorkloadName> to Kubernetes"
echo "========================================="
echo ""

NAMESPACE="workload-name"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found. Please install kubectl first."
    exit 1
fi

echo "Step 1: Creating namespace..."
kubectl apply -f namespace.yaml

echo ""
echo "Step 2: Creating secrets..."
if [ ! -f secret.yaml ]; then
    echo "Error: secret.yaml not found!"
    echo "Please copy secret.yaml.example to secret.yaml and update the values."
    exit 1
fi
kubectl apply -f secret.yaml

echo ""
echo "Step 3: Creating persistent volume claims..."
kubectl apply -f pvc.yaml

echo ""
echo "Step 4: Deploying database..."
kubectl apply -f database.yaml

echo "Waiting for database to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s

echo ""
echo "Step 5: Deploying cache..."
kubectl apply -f redis.yaml

echo "Waiting for cache to be ready..."
kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=120s

echo ""
echo "Step 6: Deploying main application..."
kubectl apply -f workload-name.yaml

echo "Waiting for application to be ready..."
kubectl wait --for=condition=ready pod -l app=workload-name -n $NAMESPACE --timeout=300s

echo ""
echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""
echo "<WorkloadName> is now running!"
echo ""
echo "Access your installation at:"
echo "  https://workload-name.mangelschots.org"
echo ""
echo "To check the status:"
echo "  kubectl get all -n $NAMESPACE"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/workload-name -n $NAMESPACE"
echo ""
```

**Make it executable:** `chmod +x deploy.sh`

## README Template

```markdown
# Workload Name

Brief description of what this application does.

## Overview

Detailed description of the application and its purpose.

**Official Website:** https://example.com  
**GitHub:** https://github.com/org/repo

## Features

- Feature 1
- Feature 2
- Feature 3

## Architecture

This deployment consists of:

- **Main Application** (image:tag)
- **PostgreSQL** (database) - if applicable
- **Redis** (caching) - if applicable

## Prerequisites

- Kubernetes cluster with kubectl access
- Traefik ingress controller
- cert-manager with Let's Encrypt DNS-01 issuer configured
- Storage class: `truenas-iscsi`

## Installation

### Quick Deploy

```bash
cd workload-name
./deploy.sh
```

### Manual Deploy

1. **Create namespace:**
   ```bash
   kubectl apply -f namespace.yaml
   ```

2. **Create secrets:**
   ```bash
   cp secret.yaml.example secret.yaml
   # Edit secret.yaml and replace placeholders
   kubectl apply -f secret.yaml
   ```

3. **Create persistent storage:**
   ```bash
   kubectl apply -f pvc.yaml
   ```

4. **Deploy database:**
   ```bash
   kubectl apply -f database.yaml
   kubectl wait --for=condition=ready pod -l app=postgres -n workload-name --timeout=300s
   ```

5. **Deploy main application:**
   ```bash
   kubectl apply -f workload-name.yaml
   kubectl wait --for=condition=ready pod -l app=workload-name -n workload-name --timeout=300s
   ```

## Access

Once deployed, access at:

**https://workload-name.mangelschots.org**

## First-Time Setup

1. Navigate to https://workload-name.mangelschots.org
2. Follow setup wizard
3. Create admin account

## Configuration

### Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `VAR_NAME` | value | Description |

### Resource Limits

**Application:**
- Requests: 100m CPU, 256Mi memory
- Limits: 1000m CPU, 1Gi memory

### Storage

- **Application Data:** 10Gi on `truenas-iscsi`

## Management

### View deployment status

```bash
kubectl get all -n workload-name
```

### View logs

```bash
kubectl logs -f deployment/workload-name -n workload-name
```

### Restart service

```bash
kubectl rollout restart deployment/workload-name -n workload-name
```

## Backup and Restore

### Backup Database

```bash
kubectl exec -n workload-name deployment/postgres -- pg_dump -U username dbname > backup.sql
```

### Restore Database

```bash
kubectl exec -i -n workload-name deployment/postgres -- psql -U username -d dbname < backup.sql
```

## Troubleshooting

### Application not starting

Check logs:
```bash
kubectl logs -f deployment/workload-name -n workload-name
```

### Database connection issues

Verify database is running:
```bash
kubectl get pods -n workload-name -l app=postgres
kubectl logs deployment/postgres -n workload-name
```

## Upgrading

To upgrade to a new version:

1. Update image tag in `workload-name.yaml`
2. Apply changes:
   ```bash
   kubectl apply -f workload-name.yaml
   ```
3. Wait for rollout:
   ```bash
   kubectl rollout status deployment/workload-name -n workload-name
   ```

## Uninstall

```bash
kubectl delete namespace workload-name
```

**Warning:** This will delete all data. Backup first!

## Support

- **Documentation:** https://docs.example.com
- **Issues:** https://github.com/org/repo/issues

## License

License information
```

## Secret Management

### .gitignore Patterns

The repository `.gitignore` already includes:
```
**/*-secret.yaml
**/*.secret.yaml
**/secret.yaml
**/secrets.yaml
```

**No additional .gitignore entries needed for individual workloads.**

### Generating Secure Random Values

```bash
# For 32-byte secrets (tokens, keys)
openssl rand -base64 32

# For 24-byte secrets (passwords)
openssl rand -base64 24

# For hexadecimal secrets
openssl rand -hex 32
```

## Common Pitfalls and Solutions

### 1. DATABASE_URL Construction

**Problem:** Kubernetes doesn't support variable substitution in plain env values.

**Solution:** Use shell wrapper:
```yaml
command:
  - /bin/sh
  - -c
  - |
    export DATABASE_URL="postgresql://user:${DB_PASSWORD}@db-svc:5432/dbname"
    exec /path/to/entrypoint.sh
```

### 2. Init Containers for Dependencies

Always wait for dependencies before starting main container:
```yaml
initContainers:
  - name: wait-for-postgres
    image: busybox:1.36
    command:
      - sh
      - -c
      - |
        until nc -z postgres-svc 5432; do
          echo "Waiting for PostgreSQL..."
          sleep 2
        done
```

### 3. Health Probes

Always include both readiness and liveness probes:
- **Readiness:** When to start accepting traffic
- **Liveness:** When to restart the container

## Best Practices Checklist

- [ ] One namespace per workload
- [ ] Use specific image tags (not `:latest` in production)
- [ ] Always set resource requests and limits
- [ ] Include health probes (readiness and liveness)
- [ ] Use init containers for dependency checking
- [ ] Secrets are gitignored with `.example` templates
- [ ] Use appropriate storage class (truenas-iscsi for databases)
- [ ] Document environment variables in README
- [ ] Create deployment script for automation
- [ ] Use consistent naming patterns
- [ ] Add proper labels to all resources
- [ ] Configure TLS for all public ingresses
- [ ] Test deployment with `kubectl apply` before committing

## Quick Reference

### Common kubectl Commands

```bash
# View all resources in namespace
kubectl get all -n namespace-name

# View logs
kubectl logs -f deployment/app-name -n namespace-name

# Describe resource
kubectl describe pod pod-name -n namespace-name

# Execute command in pod
kubectl exec -it deployment/app-name -n namespace-name -- sh

# Port forward for local testing
kubectl port-forward -n namespace-name svc/app-svc 8080:80

# Restart deployment
kubectl rollout restart deployment/app-name -n namespace-name

# Check rollout status
kubectl rollout status deployment/app-name -n namespace-name

# Delete namespace (WARNING: deletes everything)
kubectl delete namespace namespace-name
```

### Connection String Patterns

**PostgreSQL:**
```
postgresql://username:password@postgres-svc:5432/database?sslmode=prefer
```

**MySQL:**
```
mysql://username:password@mysql-svc:3306/database
```

**Redis:**
```
redis://:password@redis-svc:6379/0
```

## Examples

For reference implementations, see:
- **Simple app:** `mealie/` - Single container with database
- **Multi-service:** `plausible/` - Complex setup with multiple databases
- **With secrets:** `ghost/` - Secret management example
- **Complete setup:** `ghostfolio/` - Full-featured deployment with all patterns

---

**Last Updated:** March 2026  
**Cluster:** Kubernetes cluster at mangelschots.org
