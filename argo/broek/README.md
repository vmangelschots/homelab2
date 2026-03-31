# Broek

Simple application deployment for broek.mangelschots.org

## Container

- Image: `ghcr.io/vmangelschots/broek:latest` (private repository)
- Registry: GitHub Container Registry (ghcr.io)

## Deployment

### Prerequisites

Before deploying, ensure the image pull secret exists in the broek namespace:

```bash
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  --namespace=broek
```

Replace:
- `YOUR_GITHUB_USERNAME` with your GitHub username
- `YOUR_GITHUB_PAT` with a GitHub Personal Access Token that has `read:packages` permission

### Deploy

```bash
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
```

### Verify

Check deployment status:

```bash
kubectl get pods -n broek
kubectl get ingress -n broek
kubectl logs -n broek -l app=broek
```

## Access

Once deployed, the application will be accessible at:

https://broek.mangelschots.org

TLS certificate will be automatically provisioned via cert-manager using Let's Encrypt.

## Update

To update to the latest image:

```bash
kubectl rollout restart deployment/broek -n broek
```

## Troubleshooting

If pods fail to start with `ImagePullBackOff`:

1. Verify the secret exists: `kubectl get secret regcred -n broek`
2. Check secret details: `kubectl get secret regcred -n broek -o yaml`
3. Ensure the GitHub PAT has correct permissions
4. Verify the image exists and is accessible: `docker pull ghcr.io/vmangelschots/broek:latest`
