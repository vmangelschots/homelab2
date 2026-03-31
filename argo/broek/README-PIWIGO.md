# Piwigo - Photo Gallery for Het Broek

Piwigo is een open-source fotogalerie applicatie voor het beheren en delen van foto's online.

## Overview

Deze deployment bevat een Piwigo fotogalerie speciaal voor het Het Broek project. De applicatie is toegankelijk via https://broek-fotos.mangelschots.org

**Official Website:** https://piwigo.org  
**GitHub:** https://github.com/Piwigo/Piwigo

## Features

- Upload en beheer foto's en albums
- Gebruikersbeheer en permissies
- Galerij thema's en plugins
- Batch upload functionaliteit
- EXIF metadata ondersteuning
- Responsive design

## Architecture

Deze deployment bestaat uit:

- **Piwigo** (linuxserver/piwigo:latest) - Hoofdapplicatie
- **MariaDB 10.11** - Database voor foto metadata en gebruikers

## Prerequisites

- Kubernetes cluster met kubectl access
- Traefik ingress controller
- cert-manager met Let's Encrypt DNS-01 issuer geconfigureerd
- Storage class: `nfs-retain`

## Installation

### Quick Deploy

```bash
cd /root/cluster/argo/broek

# Maak het secret bestand aan
cp piwigo-secret.yaml.example piwigo-secret.yaml

# Genereer veilige wachtwoorden
openssl rand -base64 24

# Bewerk piwigo-secret.yaml en vervang de wachtwoorden
nano piwigo-secret.yaml

# Deploy alles
./deploy-piwigo.sh
```

### Manual Deploy

1. **Namespace bestaat al** (broek namespace wordt al gebruikt)

2. **Create secrets:**
   ```bash
   cp piwigo-secret.yaml.example piwigo-secret.yaml
   # Bewerk piwigo-secret.yaml en vervang placeholders
   kubectl apply -f piwigo-secret.yaml
   ```

3. **Create persistent storage:**
   ```bash
   kubectl apply -f piwigo-pvc.yaml
   ```

4. **Deploy MySQL database:**
   ```bash
   kubectl apply -f piwigo-mysql.yaml
   kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=piwigo-mysql -n broek --timeout=300s
   ```

5. **Deploy Piwigo:**
   ```bash
   kubectl apply -f piwigo.yaml
   kubectl wait --for=condition=ready pod -l app=piwigo -n broek --timeout=300s
   ```

## Access

Zodra gedeployed, toegankelijk via:

**https://broek-fotos.mangelschots.org**

## First-Time Setup

1. Navigeer naar https://broek-fotos.mangelschots.org
2. Volg de setup wizard
3. Database configuratie:
   - **Database Host:** `piwigo-mysql-svc`
   - **Database Name:** `piwigo`
   - **Database User:** `piwigo`
   - **Database Password:** (gebruik wachtwoord uit piwigo-secret.yaml)
4. Maak een admin account aan

## Configuration

### Environment Variables

**Piwigo Container:**
| Variable | Value | Description |
|----------|-------|-------------|
| `PUID` | 1000 | User ID voor file permissions |
| `PGID` | 1000 | Group ID voor file permissions |
| `TZ` | Europe/Brussels | Timezone |
| `PIWIGO_BASE_URL` | https://broek-fotos.mangelschots.org | Base URL voor Piwigo |

**MySQL Container:**
| Variable | Description |
|----------|-------------|
| `MYSQL_DATABASE` | Database naam (piwigo) |
| `MYSQL_USER` | Database gebruiker (piwigo) |
| `MYSQL_PASSWORD` | Database wachtwoord (uit secret) |
| `MYSQL_ROOT_PASSWORD` | Root wachtwoord (uit secret) |

### Resource Limits

**Piwigo:**
- Requests: 100m CPU, 256Mi memory
- Limits: 1000m CPU, 1Gi memory

**MySQL:**
- Requests: 100m CPU, 256Mi memory
- Limits: 1000m CPU, 1Gi memory

### Storage

- **Piwigo Data:** 50Gi op `nfs-retain` (voor foto's en config)
- **MySQL Data:** 10Gi op `nfs-retain` (voor database)

## Management

### View deployment status

```bash
kubectl get all -n broek
```

### View logs

```bash
# Piwigo logs
kubectl logs -f deployment/piwigo -n broek

# MySQL logs
kubectl logs -f deployment/piwigo-mysql -n broek
```

### Restart services

```bash
# Restart Piwigo
kubectl rollout restart deployment/piwigo -n broek

# Restart MySQL
kubectl rollout restart deployment/piwigo-mysql -n broek
```

## Backup and Restore

### Backup Database

```bash
kubectl exec -n broek deployment/piwigo-mysql -- mysqldump -u piwigo -p piwigo > piwigo-backup.sql
# (Je wordt gevraagd om het database wachtwoord)
```

### Restore Database

```bash
kubectl exec -i -n broek deployment/piwigo-mysql -- mysql -u piwigo -p piwigo < piwigo-backup.sql
```

### Backup Photos

De foto's worden opgeslagen in de `piwigo-data` PVC. Backup deze volume voor complete foto backup.

```bash
# Via een helper pod
kubectl run -i --tty --rm backup --image=busybox -n broek --overrides='
{
  "spec": {
    "containers": [{
      "name": "backup",
      "image": "busybox",
      "stdin": true,
      "tty": true,
      "volumeMounts": [{
        "name": "piwigo-data",
        "mountPath": "/backup"
      }]
    }],
    "volumes": [{
      "name": "piwigo-data",
      "persistentVolumeClaim": {
        "claimName": "piwigo-data"
      }
    }]
  }
}' -- sh
```

## Troubleshooting

### Piwigo not starting

Check logs:
```bash
kubectl logs -f deployment/piwigo -n broek
```

### Database connection issues

Verify MySQL is running:
```bash
kubectl get pods -n broek -l app.kubernetes.io/name=piwigo-mysql
kubectl logs deployment/piwigo-mysql -n broek
```

Test connection:
```bash
kubectl exec -it deployment/piwigo-mysql -n broek -- mysql -u piwigo -p piwigo
```

### Photo upload issues

Check persistent volume:
```bash
kubectl get pvc -n broek
kubectl describe pvc piwigo-data -n broek
```

Check permissions:
```bash
kubectl exec -it deployment/piwigo -n broek -- ls -la /config
```

## Upgrading

To upgrade to a new Piwigo version:

1. Update image tag in `piwigo.yaml` (of houd `:latest` voor automatische updates)
2. Apply changes:
   ```bash
   kubectl apply -f piwigo.yaml
   ```
3. Wait for rollout:
   ```bash
   kubectl rollout status deployment/piwigo -n broek
   ```

## Plugins and Themes

Plugins en themes kunnen geïnstalleerd worden via de Piwigo admin interface of door ze direct in de persistent volume te plaatsen.

## Uninstall Piwigo Only

Als je alleen Piwigo wilt verwijderen (niet de hele broek namespace):

```bash
kubectl delete -f piwigo.yaml
kubectl delete -f piwigo-mysql.yaml
kubectl delete -f piwigo-pvc.yaml
kubectl delete secret piwigo-secret -n broek
```

**Warning:** Dit verwijdert alle foto's en database data. Maak eerst een backup!

## Support

- **Documentation:** https://piwigo.org/doc/doku.php
- **Forum:** https://piwigo.org/forum/
- **GitHub Issues:** https://github.com/Piwigo/Piwigo/issues

## License

Piwigo is licensed under GPL v2.0
