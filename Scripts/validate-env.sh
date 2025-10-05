#!/bin/bash

# ====================================
# Pipster Identity Server - Environment Setup Script (Bash)
# ====================================
# This script helps set up environment files for different environments
# Usage: ./setup-env.sh [development|staging|production]
# ====================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default environment
ENVIRONMENT="${1:-development}"
FORCE="${2}"

echo -e "${CYAN}=====================================${NC}"
echo -e "${CYAN}Pipster Identity Server - Environment Setup${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""

# Validate environment
case "$ENVIRONMENT" in
    development|dev)
        ENVIRONMENT="development"
        SOURCE_FILE=".env.example"
        ;;
    staging|stg)
        ENVIRONMENT="staging"
        SOURCE_FILE=".env.staging"
        ;;
    production|prod)
        ENVIRONMENT="production"
        SOURCE_FILE=".env.production"
        ;;
    *)
        echo -e "${RED}ERROR: Invalid environment: $ENVIRONMENT${NC}"
        echo -e "${YELLOW}Usage: $0 [development|staging|production]${NC}"
        exit 1
        ;;
esac

# Check if .env already exists
if [ -f ".env" ] && [ "$FORCE" != "--force" ]; then
    echo -e "${RED}ERROR: .env file already exists!${NC}"
    echo -e "${YELLOW}Use --force to overwrite, or manually edit .env${NC}"
    echo ""
    echo -e "${YELLOW}Current .env contents:${NC}"
    head -n 5 .env
    echo "..."
    exit 1
fi

if [ -f ".env" ]; then
    echo -e "${YELLOW}WARNING: Overwriting existing .env file${NC}"
fi

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo -e "${RED}ERROR: Source file $SOURCE_FILE not found!${NC}"
    echo -e "${YELLOW}Please ensure .env.example, .env.staging, and .env.production exist${NC}"
    exit 1
fi

# Copy file
cp "$SOURCE_FILE" .env
echo -e "${GREEN}✓ Created .env from $SOURCE_FILE${NC}"

# Generate secure passwords for production
if [ "$ENVIRONMENT" = "production" ]; then
    echo ""
    echo -e "${YELLOW}=====================================${NC}"
    echo -e "${YELLOW}PRODUCTION SECURITY SETUP${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    echo ""
    echo -e "${CYAN}Generating secure random passwords...${NC}"
    
    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        echo -e "${RED}ERROR: openssl not found. Please install openssl.${NC}"
        exit 1
    fi
    
    # Generate secure passwords
    DB_PASSWORD=$(openssl rand -base64 32)
    JWT_KEY=$(openssl rand -base64 32)
    DATA_PROTECTION_KEY=$(openssl rand -base64 32)
    
    echo ""
    echo -e "${GREEN}Generated secure credentials:${NC}"
    echo -e "${YELLOW}DB Password: $DB_PASSWORD${NC}"
    echo -e "${YELLOW}JWT Signing Key: $JWT_KEY${NC}"
    echo -e "${YELLOW}Data Protection Key: $DATA_PROTECTION_KEY${NC}"
    echo ""
    echo -e "${RED}CRITICAL: Store these in Azure Key Vault!${NC}"
    echo -e "${RED}CRITICAL: Never commit .env to version control!${NC}"
    echo ""
    
    # Ask if user wants to update .env
    read -p "Update .env with generated passwords? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i.bak "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$DB_PASSWORD|g" .env
        sed -i.bak "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|g" .env
        sed -i.bak "s|JWT_SIGNING_KEY=.*|JWT_SIGNING_KEY=$JWT_KEY|g" .env
        sed -i.bak "s|DATA_PROTECTION_KEY=.*|DATA_PROTECTION_KEY=$DATA_PROTECTION_KEY|g" .env
        rm .env.bak
        echo -e "${GREEN}✓ Updated .env with generated passwords${NC}"
    fi
fi

# Show next steps
echo ""
echo -e "${CYAN}=====================================${NC}"
echo -e "${CYAN}Next Steps:${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""
echo -e "${YELLOW}1. Review and edit .env file:${NC}"
echo -e "   ${NC}vim .env${NC}"
echo ""
echo -e "${YELLOW}2. Verify configuration:${NC}"
echo -e "   ${NC}docker-compose config${NC}"
echo ""
echo -e "${YELLOW}3. Start services:${NC}"
echo -e "   ${NC}docker-compose up -d${NC}"
echo ""
echo -e "${YELLOW}4. Check health:${NC}"
echo -e "   ${NC}./test-health.sh${NC}"
echo ""

if [ "$ENVIRONMENT" = "production" ]; then
    echo -e "${RED}=====================================${NC}"
    echo -e "${RED}PRODUCTION CHECKLIST${NC}"
    echo -e "${RED}=====================================${NC}"
    echo -e "${YELLOW}[ ] Change all default passwords${NC}"
    echo -e "${YELLOW}[ ] Store secrets in Azure Key Vault${NC}"
    echo -e "${YELLOW}[ ] Configure SSL/TLS certificates${NC}"
    echo -e "${YELLOW}[ ] Set up database backups${NC}"
    echo -e "${YELLOW}[ ] Enable monitoring & alerting${NC}"
    echo -e "${YELLOW}[ ] Verify .env is in .gitignore${NC}"
    echo -e "${YELLOW}[ ] Test disaster recovery${NC}"
    echo ""
fi

echo -e "${GREEN}✓ Environment setup complete!${NC}"
echo ""

# Make script executable
chmod +x setup-env.sh 2>/dev/null || true