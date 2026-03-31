# Storage Migration: NFS to iSCSI

## Why the Change?

The original configuration used `nfs-retain` storage class, which caused permission issues (chmod errors) with PostgreSQL and ClickHouse. iSCSI block storage (`truenas-iscsi`) provides better compatibility with database workloads.

## Changes Made

### PVC Storage Class

Changed from `nfs-retain` to `truenas-iscsi` in `argo/plausible/pvc.yaml`:

```yaml
# Before
storageClassName: nfs-retain

# After
storageClassName: truenas-iscsi
```

### PostgreSQL Configuration

PostgreSQL already uses the correct subdirectory pattern to avoid iSCSI root volume issues:

```yaml
env:
  - name: PGDATA
    value: /var/lib/postgresql/data/pgdata  # Subdirectory, not root
volumeMounts:
  - name: data
    mountPath: /var/lib/postgresql/data     # Mount parent directory
```

This is **required** for iSCSI because PostgreSQL cannot initialize directly on the iSCSI volume root (lost+found issue).

### ClickHouse Configuration

ClickHouse works fine with iSCSI as-is:
- Data: `/var/lib/clickhouse`
- Logs: `/var/log/clickhouse-server`

## If You Already Deployed with NFS

If you already have Plausible running with NFS storage, you'll need to migrate your data:

### Option 1: Fresh Install (Recommended if no critical data)

1. **Backup any important data** (user accounts, site configurations):
   ```bash
   kubectl exec -n plausible deployment/plausible-postgres -- \
     pg_dump -U plausible plausible | gzip > plausible-backup.sql.gz
   ```

2. **Delete existing deployment**:
   ```bash
   kubectl delete namespace plausible
   ```

3. **Deploy with new iSCSI storage**:
   ```bash
   kubectl apply -f argo/plausible/
   ```

4. **Restore data** (if needed):
   ```bash
   gunzip -c plausible-backup.sql.gz | \
     kubectl exec -i -n plausible deployment/plausible-postgres -- \
     psql -U plausible plausible
   ```

### Option 2: Data Migration (If you have critical analytics data)

1. **Scale down Plausible**:
   ```bash
   kubectl scale deployment plausible -n plausible --replicas=0
   kubectl scale deployment plausible-postgres -n plausible --replicas=0
   kubectl scale deployment plausible-clickhouse -n plausible --replicas=0
   ```

2. **Backup all databases**:
   ```bash
   # PostgreSQL
   kubectl exec -n plausible deployment/plausible-postgres -- \
     pg_dump -U plausible plausible | gzip > postgres-backup.sql.gz
   
   # ClickHouse events table
   kubectl exec -n plausible deployment/plausible-clickhouse -- \
     clickhouse-client --query "SELECT * FROM plausible.events FORMAT CSVWithNames" | \
     gzip > clickhouse-events-backup.csv.gz
   ```

3. **Delete old PVCs** (this will delete NFS data):
   ```bash
   kubectl delete pvc -n plausible --all
   ```

4. **Update PVC manifests** to use `truenas-iscsi`

5. **Apply new PVCs**:
   ```bash
   kubectl apply -f argo/plausible/pvc.yaml
   ```

6. **Scale up deployments**:
   ```bash
   kubectl scale deployment plausible-postgres -n plausible --replicas=1
   kubectl scale deployment plausible-clickhouse -n plausible --replicas=1
   kubectl scale deployment plausible -n plausible --replicas=1
   ```

7. **Restore data**:
   ```bash
   # Wait for databases to be ready
   kubectl wait --for=condition=ready pod -l app=plausible-postgres -n plausible --timeout=300s
   
   # Restore PostgreSQL
   gunzip -c postgres-backup.sql.gz | \
     kubectl exec -i -n plausible deployment/plausible-postgres -- \
     psql -U plausible plausible
   
   # Restore ClickHouse (if needed - events can be rebuilt from tracking)
   gunzip -c clickhouse-events-backup.csv.gz | \
     kubectl exec -i -n plausible deployment/plausible-clickhouse -- \
     clickhouse-client --query "INSERT INTO plausible.events FORMAT CSVWithNames"
   ```

### Option 3: Use Both Storage Types

Keep PostgreSQL on iSCSI and use NFS for ClickHouse logs (if NFS works for logs):

```yaml
# PostgreSQL - iSCSI (required)
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: plausible-postgres-data
spec:
  storageClassName: truenas-iscsi
  
# ClickHouse Data - iSCSI (better performance)
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: plausible-clickhouse-data
spec:
  storageClassName: truenas-iscsi

# ClickHouse Logs - NFS (optional, if preferred)
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: plausible-clickhouse-logs
spec:
  storageClassName: nfs-retain
```

## Benefits of iSCSI

✅ **Better database performance** - Block storage is optimized for databases  
✅ **No permission issues** - Proper filesystem ownership  
✅ **Atomic operations** - Better consistency for database operations  
✅ **Lower latency** - Direct block access vs NFS network overhead  

## Considerations

⚠️ **ReadWriteOnce only** - iSCSI volumes can only be mounted by one pod  
⚠️ **PostgreSQL subdirectory required** - Must use PGDATA subdirectory  
⚠️ **No pod migration** - Pods must run on the node where volume is attached  

## Verification

After deployment, verify storage is working:

```bash
# Check PVCs
kubectl get pvc -n plausible

# Should show truenas-iscsi
NAME                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
plausible-postgres-data      Bound    pvc-xxx                                    10Gi       RWO            truenas-iscsi   1m
plausible-clickhouse-data    Bound    pvc-yyy                                    20Gi       RWO            truenas-iscsi   1m
plausible-clickhouse-logs    Bound    pvc-zzz                                    5Gi        RWO            truenas-iscsi   1m

# Check pods are running
kubectl get pods -n plausible

# Check PostgreSQL can write
kubectl exec -n plausible deployment/plausible-postgres -- \
  psql -U plausible -c "CREATE TABLE test (id int); DROP TABLE test;"
```

## Summary

✅ All PVCs now use `truenas-iscsi` storage class  
✅ PostgreSQL correctly uses subdirectory for iSCSI compatibility  
✅ No chmod/permission errors with iSCSI block storage  
✅ Better performance for database workloads  

If you're deploying fresh, just deploy as-is. The configuration is ready!
