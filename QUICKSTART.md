# Quick Reference Guide

## Initial Setup (One-Time)

```bash
# 1. Copy environment templates
cp .env.example .env
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# 2. Generate secrets
openssl rand -hex 32  # N8N_ENCRYPTION_KEY
openssl rand -hex 32  # N8N_JWT_SECRET
openssl rand -base64 32  # Passwords

# 3. Edit configuration files
# - .env (for local development)
# - terraform/terraform.tfvars (for production)

# 4. Test locally
docker compose up -d
open http://localhost:5678
docker compose down

# 5. Deploy to production
./scripts/deploy.sh
```

## Daily Commands

```bash
# Local Development
docker compose up -d              # Start
docker compose down               # Stop
docker compose logs -f n8n        # View logs

# Production Access
ssh root@<server_ip>              # SSH to server
cd /root && docker compose logs -f  # View logs
docker compose ps                 # Check status

# Updates
cd /root
docker compose pull
docker compose up -d

# Manual Backup
/root/backup.sh
```

## Important Files

- `.env` - Local secrets (git-ignored)
- `terraform/terraform.tfvars` - Production secrets (git-ignored)
- `deployment/.env` - Server-side secrets (created by Terraform)

## Cost

~€10/month for Hetzner CX23 server

## Versions (Latest as of Dec 2024)

- n8n: latest
- PostgreSQL: 17
- Caddy: 2
- Terraform Hetzner Provider: 1.48
- Terraform Cloudflare Provider: 5.15

