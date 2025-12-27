#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "==============================================="
echo "n8n Setup Validation"
echo "==============================================="
echo ""

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1 (missing)"
        return 1
    fi
}

check_executable() {
    if [ -x "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 (executable)"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $1 (not executable)"
        return 1
    fi
}

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 not installed"
        return 1
    fi
}

errors=0

echo "Checking required commands..."
check_command docker || ((errors++))
check_command terraform || ((errors++))
check_command ssh || ((errors++))
check_command openssl || ((errors++))
echo ""

echo "Checking project structure..."
check_file ".gitignore" || ((errors++))
check_file ".env.example" || ((errors++))
check_file "docker-compose.yml" || ((errors++))
check_file "README.md" || ((errors++))
check_file "terraform/provider.tf" || ((errors++))
check_file "terraform/variables.tf" || ((errors++))
check_file "terraform/outputs.tf" || ((errors++))
check_file "terraform/main.tf" || ((errors++))
check_file "terraform/cloud-init.yaml" || ((errors++))
check_file "terraform/terraform.tfvars.example" || ((errors++))
check_file "deployment/docker-compose.yml" || ((errors++))
check_file "deployment/Caddyfile" || ((errors++))
check_file "deployment/.env.example" || ((errors++))
check_file "deployment/backup.sh" || ((errors++))
check_file "scripts/deploy.sh" || ((errors++))
echo ""

echo "Checking file permissions..."
check_executable "scripts/deploy.sh" || ((errors++))
check_executable "deployment/backup.sh" || ((errors++))
echo ""

echo "Validating Docker Compose files..."
if docker compose -f docker-compose.yml config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} docker-compose.yml is valid"
else
    echo -e "${RED}✗${NC} docker-compose.yml has errors"
    ((errors++))
fi

if docker compose -f deployment/docker-compose.yml config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} deployment/docker-compose.yml is valid"
else
    echo -e "${RED}✗${NC} deployment/docker-compose.yml has errors"
    ((errors++))
fi
echo ""

echo "Checking Terraform formatting..."
cd terraform
if terraform fmt -check > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Terraform files are properly formatted"
else
    echo -e "${YELLOW}⚠${NC} Terraform files need formatting (run: terraform fmt)"
fi
cd ..
echo ""

echo "==============================================="
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Copy .env.example to .env and configure"
    echo "2. Copy terraform/terraform.tfvars.example to terraform/terraform.tfvars"
    echo "3. Test locally: docker compose up -d"
    echo "4. Deploy to production: ./scripts/deploy.sh"
else
    echo -e "${RED}✗ Found $errors issue(s)${NC}"
    exit 1
fi
echo "==============================================="
