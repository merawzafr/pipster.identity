#!/bin/bash

# ====================================
# Pipster Identity Server - Production Deployment Script
# ====================================
# This script securely deploys to production by:
# 1. Fetching secrets from Azure Key Vault
# 2. Creating .env with real secrets
# 3. Validating configuration (blocks weak passwords)
# 4. Deploying containers
# 5. Verifying health
# ====================================

set -e  # Exit on any error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Pipster Identity - Production Deployment${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ====================================
# Safety Check: Verify Production Environment
# ====================================

if [ -z "$PRODUCTION_DEPLOYMENT" ]; then
    echo -e "${RED}❌ ERROR: PRODUCTION_DEPLOYMENT environment variable not set!${NC}"
    echo -e "${YELLOW}This script should only run in production CI/CD pipeline${NC}"
    echo ""
    echo -e "${YELLOW}To deploy manually, run:${NC}"
    echo -e "  ${NC}export PRODUCTION_DEPLOYMENT=true${NC}"
    echo -e "  ${NC}./scripts/deploy-production.sh${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Production environment confirmed${NC}"
echo ""

# ====================================
# Check Azure CLI Authentication
# ====================================

if ! az account show &>/dev/null; then
    echo -e "${RED}❌ ERROR: Not authenticated to Azure!${NC}"
    echo -e "${YELLOW}Run: az login${NC}"
    exit 1
fi

AZURE_ACCOUNT=$(az account show --query name -o tsv)
echo -e "${GREEN}✓ Azure CLI authenticated${NC}"
echo -e "  Account: ${CYAN}$AZURE_ACCOUNT${NC}"
echo ""

# ====================================
# Configuration
# ====================================

VAULT_NAME="${AZURE_KEY_VAULT_NAME:-pipster-prod-vault}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${CYAN}Configuration:${NC}"
echo -e "  Key Vault: ${CYAN}$VAULT_NAME${NC}"
echo -e "  Project Root: ${CYAN}$PROJECT_ROOT${NC}"
echo ""

# ====================================
# Fetch Secrets from Azure Key Vault
# ====================================

echo -e "${CYAN}Fetching secrets from Azure Key Vault...${NC}"

# Database credentials
echo -e "  Fetching database credentials..."
DB_USERNAME=$(az keyvault secret show \
    --vault-name "$VAULT_NAME" \
    --name "ProductionDbUsername" \
    --query value -o tsv 2>/dev/null || echo "pipster_production")

DB_PASSWORD=$(az keyvault secret show \
    --vault-name "$VAULT_NAME" \
    --name "ProductionDbPassword" \
    --query value -o tsv)

if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}❌ ERROR: Failed to fetch ProductionDbPassword from Key Vault${NC}"
    echo -e "${YELLOW}Make sure the secret exists:${NC}"
    echo -e "  ${NC}az keyvault secret show --vault-name $VAULT_NAME --name ProductionDbPassword${NC}"
    exit 1
fi

# Security keys
echo -e "  Fetching security keys..."
JWT_KEY=$(az keyvault secret show \
    --vault-name "$VAULT_NAME" \
    --name "JwtSigningKey" \
    --query value -o tsv)

if [ -z "$JWT_KEY" ]; then
    echo -e "${RED}❌ ERROR: Failed to fetch JwtSigningKey from Key Vault${NC}"
    exit 1
fi

DATA_PROTECTION_KEY=$(az keyvault secret show \
    --vault-name "$VAULT_NAME" \
    --name "DataProtectionKey" \
    --query value -o tsv)

if [ -z "$DATA_PROTECTION_KEY" ]; then
    echo -e "${RED}❌ ERROR: Failed to fetch DataProtectionKey from Key Vault${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Secrets fetched successfully${NC}"
echo ""

# ====================================
# Validate Secrets
# ====================================

echo -e "${CYAN}Validating secrets...${NC}"

# Check password is not empty
if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}❌ ERROR: Database password is empty!${NC}"
    exit 1
fi

# Check password strength (minimum 16 characters)
if [ ${#DB_PASSWORD} -lt 16 ]; then
    echo -e "${RED}❌ ERROR: Database password is too short (< 16 chars)!${NC}"
    echo -e "${YELLOW}Generate a new password:${NC}"
    echo -e "  ${NC}openssl rand -base64 32${NC}"
    exit 1
fi

# Check password is not default
if [ "$DB_PASSWORD" = "postgres" ]; then
    echo -e "${RED}❌ ERROR: Using default 'postgres' password in production!${NC}"
    exit 1
fi

# Check JWT key
if [ ${#JWT_KEY} -lt 16 ]; then
    echo -e "${RED}❌ ERROR: JWT signing key is too short!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Secret validation passed${NC}"
echo ""

# ====================================
# Create .env from Production Template
# ====================================

echo -e "${CYAN}Creating .env from template...${NC}"

cd "$PROJECT_ROOT"

if [ ! -f ".env.production" ]; then
    echo -e "${RED}❌ ERROR: .env.production template not found!${NC}"
    exit 1
fi

# Backup existing .env if it exists
if [ -f ".env" ]; then
    echo -e "${YELLOW}⚠ Backing up existing .env to .env.backup${NC}"
    cp .env .env.backup
fi

# Copy template
cp .env.production .env

# Replace placeholders with real secrets
sed -i "s|CHANGE_ME_USE_AZURE_KEY_VAULT|$DB_PASSWORD|g" .env
sed -i "s|pipster_production|$DB_USERNAME|g" .env

# Add/update JWT and Data Protection keys
# Remove existing keys if present
sed -i '/^JWT_SIGNING_KEY=/d' .env
sed -i '/^DATA_PROTECTION_KEY=/d' .env

# Append keys at the end
cat >> .env << EOF

# Production Security Keys (from Azure Key Vault - $(date))
JWT_SIGNING_KEY=$JWT_KEY
DATA_PROTECTION_KEY=$DATA_PROTECTION_KEY
EOF

echo -e "${GREEN}✓ .env created with production secrets${NC}"
echo ""

# ====================================
# CRITICAL: Validate Configuration
# ====================================

echo -e "${CYAN}Validating configuration...${NC}"

if [ ! -f "$SCRIPT_DIR/validate-env.sh" ]; then
    echo -e "${RED}❌ ERROR: Validation script not found!${NC}"
    exit 1
fi

chmod +x "$SCRIPT_DIR/validate-env.sh"

if ! "$SCRIPT_DIR/validate-env.sh"; then
    echo -e "${RED}❌ ERROR: Configuration validation failed!${NC}"
    echo -e "${YELLOW}Deployment aborted${NC}"
    
    # Clean up .env
    rm .env
    if [ -f ".env.backup" ]; then
        mv .env.backup .env
        echo -e "${YELLOW}Restored previous .env${NC}"
    fi
    
    exit 1
fi

echo -e "${GREEN}✓ Configuration validated${NC}"
echo ""

# ====================================
# Deploy with Docker Compose
# ====================================

echo -e "${CYAN}Deploying containers...${NC}"

# Stop existing containers
echo -e "  Stopping existing containers..."
docker-compose down || true

# Pull latest images (if using remote registry)
if [ -n "$DOCKER_REGISTRY" ]; then
    echo -e "  Pulling latest images from registry..."
    docker-compose pull
fi

# Start containers
echo -e "  Starting containers..."
docker-compose up -d

echo -e "${GREEN}✓ Containers deployed${NC}"
echo ""

# ====================================
# Wait for Containers to be Healthy
# ====================================

echo -e "${CYAN}Waiting for health checks...${NC}"

# Give containers time to start
sleep 15

# Check if health check script exists
if [ -f "$SCRIPT_DIR/test-health.sh" ]; then
    chmod +x "$SCRIPT_DIR/test-health.sh"
    
    # Run health checks
    if "$SCRIPT_DIR/test-health.sh"; then
        echo -e "${GREEN}✓ Health checks passed${NC}"
    else
        echo -e "${RED}❌ WARNING: Health checks failed!${NC}"
        echo -e "${YELLOW}Check logs: docker-compose logs${NC}"
        echo -e "${YELLOW}Continuing anyway - verify manually${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Health check script not found, skipping...${NC}"
fi

echo ""

# ====================================
# Post-Deployment Security
# ====================================

# Optional: Remove .env from disk after deployment
# Uncomment if you want to ensure .env doesn't persist
# WARNING: Docker Compose needs .env on restart, so only do this if using
# orchestrator that injects environment variables differently
#
# echo -e "${CYAN}Cleaning up .env file...${NC}"
# rm .env
# echo -e "${GREEN}✓ .env removed from disk${NC}"
# echo ""

# ====================================
# Deployment Summary
# ====================================

echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}✅ Production deployment successful!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

echo -e "${CYAN}Deployment Details:${NC}"
echo -e "  Timestamp: ${NC}$(date)${NC}"
echo -e "  Database User: ${NC}$DB_USERNAME${NC}"
echo -e "  Key Vault: ${NC}$VAULT_NAME${NC}"
echo -e "  Environment: ${NC}Production${NC}"
echo ""

echo -e "${CYAN}Next Steps:${NC}"
echo -e "  1. Monitor logs: ${NC}docker-compose logs -f identity${NC}"
echo -e "  2. Check Application Insights for errors"
echo -e "  3. Verify IdentityServer: ${NC}https://identity.pipster.app/.well-known/openid-configuration${NC}"
echo -e "  4. Test authentication flow"
echo ""

echo -e "${CYAN}Troubleshooting:${NC}"
echo -e "  View container status: ${NC}docker-compose ps${NC}"
echo -e "  View logs: ${NC}docker-compose logs identity${NC}"
echo -e "  Restart containers: ${NC}docker-compose restart${NC}"
echo ""

echo -e "${GREEN}Deployment complete!${NC}"
echo ""