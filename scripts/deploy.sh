#!/bin/bash
set -euo pipefail

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SSH_KEY_PATH="${REPO_ROOT}/id_rsa"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if SSH key exists and has correct permissions
check_ssh_key() {
    log_info "Checking SSH key..."
    
    if [ ! -f "$SSH_KEY_PATH" ]; then
        log_error "SSH private key not found at: $SSH_KEY_PATH"
        log_info "Please ensure you have placed your SSH private key (id_rsa) in the repo root"
        log_info "The public key (id_rsa.pub) should also be present"
        exit 1
    fi
    
    # Check permissions (should be 600)
    local perms=$(stat -f "%OLp" "$SSH_KEY_PATH" 2>/dev/null || stat -c "%a" "$SSH_KEY_PATH" 2>/dev/null)
    if [ "$perms" != "600" ]; then
        log_warn "SSH key has incorrect permissions: $perms (should be 600)"
        log_info "Fixing permissions..."
        chmod 600 "$SSH_KEY_PATH"
        log_info "Permissions fixed"
    fi
    
    log_info "SSH key found and verified"
}

# Check if required commands are available
check_requirements() {
    log_info "Checking requirements..."
    
    local missing=0
    
    if ! command -v terraform &> /dev/null; then
        log_error "terraform is not installed"
        missing=1
    fi
    
    if ! command -v ssh &> /dev/null; then
        log_error "ssh is not installed"
        missing=1
    fi
    
    if [ -z "${GHCR_USER:-}" ] || [ -z "${GHCR_TOKEN:-}" ]; then
        log_error "GHCR_USER and GHCR_TOKEN env vars must be set for GHCR image pull"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        log_error "Please install missing requirements"
        exit 1
    fi
    
    log_info "All requirements satisfied"
}

# Initialize Terraform
terraform_init() {
    log_info "Initializing Terraform..."
    cd terraform
    terraform init
    cd ..
}

# Validate Terraform configuration
terraform_validate() {
    log_info "Validating Terraform configuration..."
    cd terraform
    terraform validate
    cd ..
}

# Plan Terraform changes
terraform_plan() {
    log_info "Planning Terraform changes..."
    cd terraform
    terraform plan -out=tfplan
    cd ..
}

# Apply Terraform changes
terraform_apply() {
    log_info "Applying Terraform changes..."
    cd terraform
    terraform apply tfplan
    rm -f tfplan
    cd ..
}

# Get server IP from Terraform output
get_server_ip() {
    cd terraform
    terraform output -raw server_ip
    cd ..
}

# Wait for server to be ready
wait_for_server() {
    local server_ip=$1
    local max_attempts=30
    local attempt=0
    
    log_info "Waiting for server to be ready..."
    
    while [ $attempt -lt $max_attempts ]; do
        if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"$server_ip" "echo 'Server is ready'" &> /dev/null; then
            log_info "Server is ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        log_info "Attempt $attempt/$max_attempts - waiting for server..."
        sleep 10
    done
    
    log_error "Server did not become ready in time"
    return 1
}

# Deploy to server
deploy_to_server() {
    local server_ip=$1
    
    log_info "Deploying to server at $server_ip..."
    
    # Wait for cloud-init to complete
    log_info "Waiting for cloud-init to complete (this may take a few minutes)..."
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@"$server_ip" "cloud-init status --wait" || true
    
    log_info "Logging in to GHCR on server..."
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@"$server_ip" \
        "echo \"${GHCR_TOKEN}\" | docker login ghcr.io -u ${GHCR_USER} --password-stdin"
    
    log_info "Pulling linkedin-analytics image..."
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@"$server_ip" \
        "docker pull ghcr.io/alialfredji/linkedin-analytics:latest"
    
    log_info "Checking Docker services..."
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@"$server_ip" "docker ps"
    
    log_info "Deployment completed!"
}

# Show deployment info
show_info() {
    log_info "========================================="
    log_info "Deployment Information"
    log_info "========================================="
    
    cd terraform
    echo ""
    terraform output
    cd ..
    
    log_info "========================================="
    log_info "Next Steps:"
    log_info "1. Wait a few minutes for SSL certificate provisioning"
    log_info "2. Access n8n at the URL shown above"
    log_info "3. Use the basic auth credentials from your terraform.tfvars"
    log_info "========================================="
}

# Main deployment flow
main() {
    log_info "Starting deployment..."
    
    check_requirements
    check_ssh_key
    
    # Check if terraform.tfvars exists
    if [ ! -f terraform/terraform.tfvars ]; then
        log_error "terraform/terraform.tfvars not found!"
        log_info "Please copy terraform/terraform.tfvars.example to terraform/terraform.tfvars and fill in your values"
        exit 1
    fi
    
    terraform_init
    terraform_validate
    terraform_plan
    
    # Ask for confirmation
    echo ""
    log_warn "Review the plan above. Do you want to proceed? (yes/no)"
    read -r response
    
    if [ "$response" != "yes" ]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    terraform_apply
    
    local server_ip
    server_ip=$(get_server_ip)
    
    wait_for_server "$server_ip"
    deploy_to_server "$server_ip"
    
    show_info
    
    log_info "Deployment completed successfully!"
}

# Run main function
main

