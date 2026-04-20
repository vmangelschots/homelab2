# Homelab2 — GitOps Repository

## Overview

This is a **Kubernetes homelab GitOps repository** using raw Kubernetes manifests (no Helm templating, no Kustomize overlays). All workloads are deployed via `kubectl apply`. The cluster runs **Talos Linux**.

## Repository Structure

```
homelab2/
├── argo/          # All workload manifests (one directory per app)
└── setup/         # Cluster infrastructure (storage, ingress, certs, MetalLB, Talos)
```

Each workload under `argo/` follows this layout:

**Simple app:**
```
app-name/
├── namespace.yaml
├── pvc.yaml          (if storage needed)
├── app-name.yaml     (Deployment + Service + Ingress bundled)
└── README.md
```

**Complex app (with database/cache):**
```
app-name/
├── namespace.yaml
├── pvc.yaml
├── secret.yaml        (gitignored)
├── secret.yaml.example
├── configmap.yaml     (optional)
├── postgres.yaml / mysql.yaml
├── redis.yaml
├── app-name.yaml
├── deploy.sh          (optional ordered deployment script)
└── README.md
```

## Cluster Hardware

- **OS:** Talos Linux (configured via `setup/apply-talos.sh` and `talosctl`)
- **Control plane:** chronos, metis, themis (192.168.20.x)
- **Workers:** argus, hercules (Intel GPU workers — udev rules for DRM/render devices)
- **Internal domain:** `*.olympus.internal`

## Networking

| Network | Subnet | Purpose |
|---|---|---|
| Kubernetes | 192.168.20.0/24 (ens18) | Primary node comms |
| Storage | 192.168.30.0/24 (ens19) | TrueNAS traffic |
| Management/LB | 192.168.40.0/24 | MetalLB LoadBalancer IPs |

**MetalLB** provides LoadBalancer IPs from `192.168.40.100–192.168.40.199` (L2 advertisement).

## Ingress — Traefik

- **Ingress class:** `traefik`
- **LoadBalancer IP:** `192.168.40.101` (static via MetalLB)
- **Entrypoints:** `web`, `websecure`
- **Prometheus metrics:** enabled

Standard ingress annotation pattern:
```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-dns01
  traefik.ingress.kubernetes.io/router.entrypoints: websecure
```

**Internal-only middleware** (`setup/traefik/local-middelware.yaml`):
- Middleware name: `internal-whitelist`
- Allowed ranges: `192.168.0.0/16`, `172.21.0.0/16`, `10.0.0.0/8`

## TLS — cert-manager + Let's Encrypt

- **ClusterIssuer:** `letsencrypt-dns01`
- **Challenge type:** DNS-01 via Cloudflare
- **Admin email:** vincent@mangelschots.org
- **Cloudflare token secret:** `cloudflare-api-token`
- **ACME account key secret:** `acme-account-key`
- **TLS secret naming pattern:** `{app}-mangelschots-org-tls`
- **Domain pattern:** `<app>.mangelschots.org`

## Storage

Three storage classes are available:

### `truenas-iscsi` — Block storage (RWO)
- **Driver:** democratic-csi (freenas-api-iscsi)
- **TrueNAS host:** `192.168.30.4:443`
- **ZFS dataset:** `large_pool/k8s_iscsi/volumes`
- **iSCSI portal:** `192.168.30.4:3260`
- **Reclaim policy:** Retain
- **Use for:** Databases (PostgreSQL, MySQL), stateful apps needing block storage

### `nfs-retain` — NFS shared storage (RWX)
- **NFS server:** `192.168.30.4`
- **Export path:** `/mnt/large_pool/k8s/retain`
- **Path pattern:** `${.PVC.namespace}/${.PVC.name}`
- **Mount options:** `nfsvers=4.1, noatime`
- **Reclaim policy:** Retain
- **Use for:** Shared data, general application storage, media files

### `nfs-delete` — NFS scratch storage (RWX)
- **Export path:** `/mnt/large_pool/k8s/deletepool`
- **Path pattern:** `scratch/${.PVC.namespace}/${.PVC.name}`
- **Reclaim policy:** Delete (archives on delete as safety net)
- **Use for:** Temporary/ephemeral data

## Secret Management

Secrets are **gitignored**; example templates are committed:

```
argo/.gitignore rules:
  **/*-secret.yaml
  **/*.secret.yaml
  **/secret.yaml
  **/secrets.yaml
  !**/*.example
```

A small number of apps use **Bitnami SealedSecrets** (encrypted manifests committed to git):
- `vaultwarden-sealedsecret.yaml`, `influx-sealedsecret.yaml`, `bwalink-sealedsecret.yaml`

Secret generation:
```bash
openssl rand -base64 32   # passwords
openssl rand -base64 64   # secret keys
# URL-safe: pipe through tr '+/' '-_'
```

## Manifest Conventions

### Naming
- Service name: `<app>-svc`
- Namespace: one per workload, named after the app
- Labels: `app.kubernetes.io/name` and `app.kubernetes.io/instance`

### Resource sizing
| Tier | CPU request | CPU limit | RAM request | RAM limit |
|---|---|---|---|---|
| Small (nginx, static) | 50–100m | 500m | 128–256Mi | 512Mi |
| Database (PostgreSQL) | 100m | 1000m | 256Mi | 2Gi |
| Cache (Redis) | 50m | 500m | 128Mi | 512Mi |

### Health probes
```yaml
readinessProbe:
  initialDelaySeconds: 5–10
  timeoutSeconds: 2–5
livenessProbe:
  initialDelaySeconds: 20–30
  timeoutSeconds: 2–5
```

### Database init pattern
Use an init container with `nc -z <host> <port>` to wait for the database before starting the app.

### External service proxying
For LXC/VM services that need K8s ingress exposure, use an ExternalName Service or headless Service pointing at the VM IP (see `argo/jellyfin/external-proxy.yaml` for an example).

## Deployed Workloads

| Category | Apps |
|---|---|
| Media | jellyfin, bazarr, sabnzbd, radarr, sonarr, prowlarr, jellyseer |
| Finance | firefly, ghostfolio, actual |
| Content/Docs | ghost, broek (piwigo), paperless, mealie |
| Productivity | wekan, scrumpoker, n8n |
| AI/LLM | ollama, oobabooga |
| Home IoT | zigbee2mqtt, jacuzzicontroller |
| Monitoring | prometheus, grafana, influxdb, proxmox-exporter |
| Security | vaultwarden |
| Analytics | plausible |
| Misc | cellarium, tafels, mmbc, freezerbuddysite, bwalink, nova |

## ArgoCD

ArgoCD ingress is configured at `setup/argo/ingress.yaml` (domain: `argocd.olympus.internal`, insecure mode). The full GitOps CD flow via ArgoCD is planned but not yet the primary deployment method — current deployment is manual `kubectl apply`.

## Key Files

| File | Purpose |
|---|---|
| `argo/WORKLOAD_STANDARDS.md` | Detailed standards and patterns for new workloads |
| `setup/traefik/traefik-values.yaml` | Traefik Helm values |
| `setup/traefik/local-middelware.yaml` | Internal whitelist middleware |
| `setup/cert-manager/clusterissuer-dns-01.cloudflare.yaml` | Let's Encrypt ClusterIssuer |
| `setup/iscsi-storage/iscsi-truenas.yaml` | iSCSI storage class |
| `setup/nfs-storage/values-nfs-retain.yaml` | NFS-retain storage class |
| `setup/metallb/metallb-ip-pool.yaml` | MetalLB IP pool |
| `setup/apply-talos.sh` | Talos cluster bootstrap script |
