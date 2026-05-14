# Satisfactory Dedicated Server

Dedicated server for [Satisfactory](https://www.satisfactorygame.com/) — the factory-building game by Coffee Stain Studios.

**Docker image:** [wolveix/satisfactory-server](https://github.com/wolveix/satisfactory-server)

## Architecture

- **Satisfactory server** — auto-updates via SteamCMD on each start
- **Storage** — 20Gi NFS (`nfs-retain`) mounted at `/config`
- **Networking** — MetalLB `LoadBalancer` (UDP, no Traefik ingress)

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 7777 | UDP | Game (players connect here) |
| 15000 | UDP | Beacon |
| 15777 | UDP | Server query |

## Deployment

```bash
cd argo/satisfactory
./deploy.sh
```

Or manually:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f pvc.yaml
kubectl apply -f satisfactory.yaml
```

**Note:** First startup downloads ~5 GB via Steam — allow up to 10 minutes.

## Finding the server IP

```bash
kubectl get svc satisfactory-svc -n satisfactory
```

The `EXTERNAL-IP` is the MetalLB-assigned LAN address. Connect in-game via `<IP>:7777`.

## First-Time Setup

1. Launch Satisfactory and go to **Server Manager**
2. Add server: `<EXTERNAL-IP>:7777`
3. The first player to join as admin sets the admin password via the in-game UI

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MAXPLAYERS` | `4` | Maximum concurrent players |
| `STEAMBETA` | `false` | Use experimental branch |
| `ROOTLESS` | `false` | Run as non-root (change PUID/PGID accordingly) |

To change max players or other settings, edit `satisfactory.yaml` and re-apply.

## Resources

- **Requests:** 1 CPU, 4Gi RAM
- **Limits:** 6 CPU, 12Gi RAM
- **Storage:** 20Gi NFS

## Management

```bash
# View logs
kubectl logs -f deployment/satisfactory -n satisfactory

# Restart (e.g. to pick up a game update)
kubectl rollout restart deployment/satisfactory -n satisfactory

# Status
kubectl get all -n satisfactory
```

## Saves

Game saves are stored in `/config/gamefiles/FactoryGame/Saved/` on the NFS volume. They persist across pod restarts.

To back up saves locally:

```bash
kubectl exec -n satisfactory deployment/satisfactory -- tar czf - /config/gamefiles/FactoryGame/Saved > satisfactory-saves-$(date +%Y%m%d).tar.gz
```

## Uninstall

```bash
kubectl delete namespace satisfactory
# PVC is retained — delete manually if you want to remove data:
# kubectl delete pvc satisfactory-data -n satisfactory
```
