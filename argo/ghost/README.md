# Ghost Blog Deployment

Ghost blogging platform deployment for Kubernetes.

## Components

- **Ghost 5 (Alpine)**: Blogging platform
- **MariaDB 10.11**: Database backend
- **Persistent Storage**: NFS-backed storage for data persistence
- **Ingress**: Traefik ingress with TLS certificate

## Deployment

### 1. Create Secrets

Copy the example secrets and edit with your actual credentials:

```bash
# MySQL credentials
cp mysql-secret.yaml.example mysql-secret.yaml
# Edit mysql-secret.yaml with your actual passwords
kubectl apply -f mysql-secret.yaml

# SMTP credentials (Mailgun)
cp smtp-secret.yaml.example smtp-secret.yaml
# Edit smtp-secret.yaml with your actual Mailgun SMTP password
kubectl apply -f smtp-secret.yaml
```

### 2. Deploy Ghost

```bash
kubectl apply -f namespace.yaml
kubectl apply -f pvc.yaml
kubectl apply -f mysql.yaml
kubectl apply -f ghost.yaml
```

### 3. Verify Deployment

```bash
kubectl get all -n ghost
kubectl get ingress -n ghost
kubectl get certificate -n ghost
```

## Access

- **Blog**: https://blog.mangelschots.org
- **Admin**: https://blog.mangelschots.org/ghost

## Files

- `namespace.yaml` - Kubernetes namespace
- `pvc.yaml` - Persistent volume claims for MySQL and Ghost
- `mysql.yaml` - MariaDB deployment and service
- `mysql-secret.yaml` - MySQL passwords (NOT committed to git)
- `mysql-secret.yaml.example` - Template for MySQL secret file
- `smtp-secret.yaml` - Mailgun SMTP password (NOT committed to git)
- `smtp-secret.yaml.example` - Template for SMTP secret file
- `ghost.yaml` - Ghost deployment, service, and ingress

## Email Configuration

Ghost is configured to use Mailgun for email functionality:
- SMTP via `smtp.eu.mailgun.org:587`
- Configured for password resets, staff invitations, newsletters, and notifications
- Credentials stored securely in `smtp-secret.yaml` (NOT committed to git)

## Notes

- Secrets are excluded from git via `.gitignore`
- Database passwords are stored in `mysql-secret.yaml` (keep this file secure)
- Mailgun credentials are stored in `smtp-secret.yaml` (keep this file secure)
- Ghost uses NFS storage via the `nfs-retain` storage class
