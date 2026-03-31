#!/bin/bash
set -e

echo "======================================"
echo "Plausible Analytics Deployment Script"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if secret key is set
check_secret() {
    if grep -q "CHANGE_ME_GENERATE_A_RANDOM_SECRET_KEY_BASE_WITH_OPENSSL" argo/plausible/secret.yaml; then
        echo -e "${RED}ERROR: Secret key not configured!${NC}"
        echo ""
        echo "Generate secure secrets:"
        echo "  # Plausible secret key (64 bytes)"
        echo "  openssl rand -base64 64 | tr -d '\\n'"
        echo ""
        echo "  # PostgreSQL password (32 bytes)"
        echo "  openssl rand -base64 32"
        echo ""
        echo "  # ClickHouse password (32 bytes)"
        echo "  openssl rand -base64 32"
        echo ""
        echo "Then update argo/plausible/secret.yaml with all three values"
        exit 1
    fi
    
    if grep -q "CHANGE_ME_GENERATE_POSTGRES_PASSWORD" argo/plausible/secret.yaml; then
        echo -e "${RED}ERROR: PostgreSQL password not configured!${NC}"
        echo ""
        echo "Generate: openssl rand -base64 32"
        echo "Update argo/plausible/secret.yaml"
        exit 1
    fi
    
    if grep -q "CHANGE_ME_GENERATE_CLICKHOUSE_PASSWORD" argo/plausible/secret.yaml; then
        echo -e "${RED}ERROR: ClickHouse password not configured!${NC}"
        echo ""
        echo "Generate: openssl rand -base64 32"
        echo "Update argo/plausible/secret.yaml"
        exit 1
    fi
}

# Deploy Plausible
deploy_plausible() {
    echo -e "${GREEN}Deploying Plausible Analytics...${NC}"
    
    kubectl apply -f argo/plausible/namespace.yaml
    echo "✓ Namespace created"
    
    kubectl apply -f argo/plausible/pvc.yaml
    echo "✓ PVCs created"
    
    kubectl apply -f argo/plausible/configmap.yaml
    echo "✓ ConfigMap created"
    
    kubectl apply -f argo/plausible/secret.yaml
    echo "✓ Secret created"
    
    kubectl apply -f argo/plausible/postgres.yaml
    echo "✓ PostgreSQL deployed"
    
    kubectl apply -f argo/plausible/clickhouse.yaml
    echo "✓ ClickHouse deployed"
    
    sleep 5
    
    echo ""
    echo -e "${YELLOW}Waiting for databases to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=plausible-postgres -n plausible --timeout=300s
    kubectl wait --for=condition=ready pod -l app=plausible-clickhouse -n plausible --timeout=300s
    echo "✓ Databases ready"
    
    echo ""
    kubectl apply -f argo/plausible/plausible.yaml
    echo "✓ Plausible app deployed"
    
    echo ""
    echo -e "${YELLOW}Waiting for Plausible to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=plausible -n plausible --timeout=300s
    echo "✓ Plausible ready"
}

# Deploy analytics-enabled services
deploy_analytics_services() {
    echo ""
    echo -e "${GREEN}Deploying analytics-enabled services...${NC}"
    
    read -p "Deploy Scrumpoker with analytics? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "argo/scrumpoker/scrumpoker.yaml" ] && [ ! -f "argo/scrumpoker/scrumpoker-original.yaml" ]; then
            cp argo/scrumpoker/scrumpoker.yaml argo/scrumpoker/scrumpoker-original.yaml
            echo "✓ Backed up original scrumpoker config"
        fi
        kubectl apply -f argo/scrumpoker/scrumpoker-with-analytics.yaml
        echo "✓ Scrumpoker with analytics deployed"
    fi
    
    read -p "Deploy Jellyseerr with analytics? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "argo/jellyseer/deployment.yaml" ] && [ ! -f "argo/jellyseer/deployment-original.yaml" ]; then
            cp argo/jellyseer/deployment.yaml argo/jellyseer/deployment-original.yaml
            echo "✓ Backed up original jellyseerr config"
        fi
        kubectl apply -f argo/jellyseer/deployment-with-analytics.yaml
        echo "✓ Jellyseerr with analytics deployed"
    fi
}

# Create admin account
create_admin() {
    echo ""
    echo -e "${GREEN}Creating admin account...${NC}"
    echo ""
    
    read -p "Enter admin email: " admin_email
    read -p "Enter admin name: " admin_name
    read -sp "Enter admin password: " admin_password
    echo ""
    
    kubectl exec -n plausible deployment/plausible -- \
        /entrypoint.sh db seed \
        --email="$admin_email" \
        --name="$admin_name" \
        --password="$admin_password"
    
    echo ""
    echo -e "${GREEN}✓ Admin account created${NC}"
}

# Show next steps
show_next_steps() {
    echo ""
    echo "======================================"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo "======================================"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Visit https://analytics.mangelschots.org"
    echo "2. Login with your admin credentials"
    echo "3. Add these sites:"
    echo "   - blog.mangelschots.org"
    echo "   - scrumpoker.mangelschots.org"
    echo "   - requests.mangelschots.org"
    echo ""
    echo "4. For Ghost blog:"
    echo "   - Login to https://blog.mangelschots.org/ghost"
    echo "   - Go to Settings → Code Injection"
    echo "   - Add to Site Header:"
    echo "     <script defer data-domain=\"blog.mangelschots.org\" src=\"https://analytics.mangelschots.org/js/script.js\"></script>"
    echo ""
    echo "5. Verify tracking by visiting each site"
    echo ""
    echo "For detailed instructions, see:"
    echo "  argo/plausible/SETUP.md"
    echo ""
}

# Main
main() {
    check_secret
    deploy_plausible
    deploy_analytics_services
    
    read -p "Create admin account now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_admin
    else
        echo ""
        echo -e "${YELLOW}Create admin account later with:${NC}"
        echo "  kubectl exec -it -n plausible deployment/plausible -- /bin/sh"
        echo "  /entrypoint.sh db seed --email=admin@example.com --name=\"Admin\" --password=\"password\""
    fi
    
    show_next_steps
}

main
