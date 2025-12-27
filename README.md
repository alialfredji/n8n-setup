# n8n Self-Hosted Setup

Production-ready n8n deployment on Hetzner Cloud with Terraform, Docker, PostgreSQL, and Caddy reverse proxy.

## Stack

- **Orchestration**: Docker Compose
- **Database**: PostgreSQL 17
- **Reverse Proxy**: Caddy 2 (automatic SSL via Let's Encrypt)
- **Infrastructure**: Terraform (Hetzner Cloud + Cloudflare DNS)
- **Automation**: n8n (latest)

## Features

- 🔒 **Secure**: Firewall rules, SSH key-only access, fail2ban, automatic security updates
- 🌐 **Production-Ready**: Automatic SSL certificates, reverse proxy, proper DNS setup
- 💾 **Persistent Data**: PostgreSQL with automated backups
- 🚀 **Easy Deployment**: Single command deployment script
- 📦 **Multi-Service Ready**: Architecture supports adding additional services
- 🔐 **Secrets Management**: Environment-based secrets, never committed to git

## Architecture

### Local Development
```
Docker Compose
├── n8n (port 5678)
└── PostgreSQL 17
```

### Production (Hetzner)
```
Caddy (ports 80, 443)
├── Auto SSL (Let's Encrypt)
└── Reverse Proxy
    └── n8n
        └── PostgreSQL 17
```

## Prerequisites

### Required Tools
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Docker](https://docs.docker.com/get-docker/)
- SSH client
- OpenSSL (for generating secrets)

### Required Accounts & Credentials
1. **Hetzner Cloud**
   - Account with API token
   - [Create token here](https://console.hetzner.cloud/)

2. **Cloudflare**
   - Account with API token (DNS edit permissions)
   - Domain with DNS managed by Cloudflare
   - [Create token here](https://dash.cloudflare.com/profile/api-tokens)

3. **SSH Key Pair**
   - Generate if needed: `ssh-keygen -t rsa -b 4096 -C "your_email@example.com"`

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone <your-repo-url>
cd n8n-setup

# Copy environment templates
cp .env.example .env
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

### 2. Generate Secrets

```bash
# Generate n8n encryption keys
openssl rand -hex 32  # Use for N8N_ENCRYPTION_KEY
openssl rand -hex 32  # Use for N8N_USER_MANAGEMENT_JWT_SECRET

# Generate secure passwords (or use password manager)
openssl rand -base64 32  # For PostgreSQL and basic auth passwords
```

### 3. Configure Local Environment

Edit `.env`:
```bash
N8N_ENCRYPTION_KEY=<generated_key>
N8N_USER_MANAGEMENT_JWT_SECRET=<generated_key>
POSTGRES_PASSWORD=<secure_password>
```

### 4. Test Local Development

```bash
# Start local stack
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f

# Access n8n
open http://localhost:5678
```

Stop local stack when done:
```bash
docker compose down
```

### 5. Configure Terraform

Edit `terraform/terraform.tfvars`:

```hcl
# Hetzner Cloud API Token
hcloud_token = "your_hetzner_api_token"

# Cloudflare Configuration
cloudflare_api_token = "your_cloudflare_api_token"
cloudflare_zone_id   = "your_cloudflare_zone_id"

# Domain Configuration
domain = "n8n.yourdomain.com"

# SSH Configuration (paste your public key)
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."

# Server Configuration
server_name     = "n8n-server"
server_type     = "cx23"
server_location = "nbg1"  # Nuremberg, Germany

# n8n Configuration (use generated keys)
n8n_encryption_key      = "<generated_key>"
n8n_jwt_secret          = "<generated_key>"
n8n_basic_auth_user     = "admin"
n8n_basic_auth_password = "<secure_password>"

# PostgreSQL Configuration
postgres_db       = "n8n"
postgres_user     = "n8n"
postgres_password = "<secure_password>"
```

### 6. Deploy to Production

```bash
# Run deployment script
./scripts/deploy.sh
```

The script will:
1. Initialize Terraform
2. Validate configuration
3. Show deployment plan
4. Ask for confirmation
5. Provision infrastructure
6. Configure server
7. Deploy Docker stack
8. Show access information

**Deployment takes ~5-10 minutes** (server provisioning, Docker installation, SSL certificate generation).

### 7. Access n8n

After deployment completes:

1. Wait 2-3 minutes for SSL certificate provisioning
2. Visit `https://n8n.yourdomain.com`
3. Use basic auth credentials from `terraform.tfvars`

## Project Structure

```
n8n-setup/
├── .gitignore                    # Git ignore rules
├── .env.example                  # Local env template
├── docker-compose.yml            # Local development stack
├── README.md                     # This file
│
├── terraform/
│   ├── provider.tf               # Terraform providers
│   ├── variables.tf              # Variable definitions
│   ├── outputs.tf                # Outputs (IP, domain, etc.)
│   ├── main.tf                   # Main resources
│   ├── cloud-init.yaml           # Server bootstrap script
│   ├── terraform.tfvars.example  # Terraform config template
│   └── terraform.tfvars          # Your config (git-ignored)
│
├── deployment/
│   ├── docker-compose.yml        # Production stack
│   ├── Caddyfile                 # Caddy reverse proxy config
│   ├── backup.sh                 # Backup script
│   └── .env.example              # Production env template
│
└── scripts/
    └── deploy.sh                 # Deployment automation
```

## Management

### SSH Access

```bash
# Get server IP
cd terraform
terraform output server_ip

# SSH to server
ssh root@<server_ip>
```

### View Logs

```bash
# SSH to server first
ssh root@<server_ip>

# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f n8n
docker compose logs -f postgres
docker compose logs -f caddy
```

### Update n8n

```bash
# SSH to server
ssh root@<server_ip>

# Pull latest images
cd /root
docker compose pull

# Restart services
docker compose up -d
```

### Manual Backup

```bash
# SSH to server
ssh root@<server_ip>

# Run backup script
/root/backup.sh
```

Automated backups run daily at 2 AM via cron.

### Restore from Backup

```bash
# SSH to server
ssh root@<server_ip>

# Stop n8n
docker compose stop n8n

# Restore database
zcat /root/backups/n8n_backup_TIMESTAMP.sql.gz | docker exec -i n8n_postgres psql -U n8n -d n8n

# Restore n8n data
docker run --rm -v n8n_data:/data -v /root/backups:/backup alpine tar xzf /backup/n8n_data_TIMESTAMP.tar.gz -C /data

# Start n8n
docker compose start n8n
```

## Security

### Implemented Measures

- ✅ **Firewall**: Only ports 22 (SSH), 80 (HTTP), 443 (HTTPS) exposed
- ✅ **SSH**: Key-based authentication only, password auth disabled
- ✅ **Fail2ban**: Automatic IP banning after failed SSH attempts
- ✅ **Auto-Updates**: Unattended security updates enabled
- ✅ **SSL/TLS**: Automatic Let's Encrypt certificates via Caddy
- ✅ **Basic Auth**: n8n protected with username/password
- ✅ **Secrets**: All sensitive data in environment variables, never in code

### Best Practices

1. **Use strong passwords** (30+ characters, generated)
2. **Rotate secrets periodically** (every 90 days recommended)
3. **Keep backups secure** (consider encryption for offsite storage)
4. **Monitor logs regularly** (`/var/log/auth.log`, `/var/log/fail2ban.log`)
5. **Update regularly** (Docker images, OS packages)

## Cost Estimate

| Item | Monthly Cost |
|------|-------------|
| Hetzner CX23 Server | €10.00 |
| Hetzner Traffic (Included) | €0.00 |
| Total | **~€10.00/month** |

- First 20TB traffic included
- No extra charges for Cloudflare DNS

## Troubleshooting

### Deployment fails at Terraform apply

**Issue**: Authentication error

**Solution**: 
- Verify API tokens are correct in `terraform.tfvars`
- Check token permissions (Hetzner: Read & Write, Cloudflare: DNS Edit)

### Cannot SSH to server

**Issue**: Connection timeout

**Solution**:
- Wait 2-3 minutes after deployment
- Verify firewall allows port 22: `cd terraform && terraform show | grep firewall`
- Check correct SSH key is used

### SSL certificate not provisioning

**Issue**: HTTPS shows certificate error

**Solution**:
- Wait 3-5 minutes (Caddy needs time to request certificate)
- Verify DNS is correctly pointed: `dig n8n.yourdomain.com`
- Check Caddy logs: `ssh root@<ip> "docker compose logs caddy"`

### n8n won't start

**Issue**: Container keeps restarting

**Solution**:
```bash
# SSH to server
ssh root@<server_ip>

# Check logs
docker compose logs n8n

# Common fixes:
# 1. Check environment variables
cat /root/.env

# 2. Verify PostgreSQL is healthy
docker compose ps

# 3. Restart stack
docker compose down && docker compose up -d
```

### Lost encryption key

**Issue**: Cannot decrypt credentials after server rebuild

**Solution**: 
- **Prevention is key**: Backup `/home/node/.n8n` volume (done automatically)
- Encryption key must match original - never regenerate
- Restore from backup that includes n8n data volume

## Adding Additional Services

The architecture supports multiple services behind Caddy:

1. **Add to `deployment/docker-compose.yml`**:
```yaml
services:
  # ... existing services ...
  
  newservice:
    image: your-service:latest
    container_name: newservice
    restart: unless-stopped
    networks:
      - app-network
```

2. **Update `deployment/Caddyfile`**:
```caddyfile
n8n.yourdomain.com {
    reverse_proxy n8n:5678
}

newservice.yourdomain.com {
    reverse_proxy newservice:PORT
}
```

3. **Add DNS record in Terraform**:
```hcl
resource "cloudflare_record" "newservice" {
  zone_id = var.cloudflare_zone_id
  name    = "newservice"
  content = hcloud_server.n8n.ipv4_address
  type    = "A"
  ttl     = 1
  proxied = false
}
```

## Useful Commands

```bash
# Local development
docker compose up -d              # Start
docker compose down               # Stop
docker compose ps                 # Status
docker compose logs -f            # Logs

# Terraform
cd terraform
terraform plan                    # Preview changes
terraform apply                   # Apply changes
terraform destroy                 # Destroy infrastructure
terraform output                  # Show outputs

# Production management
ssh root@<ip>                     # SSH to server
docker compose ps                 # Check status
docker compose logs -f            # View logs
docker compose pull && docker compose up -d  # Update
/root/backup.sh                   # Manual backup
```

## Support & Resources

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Community](https://community.n8n.io/)
- [Hetzner Cloud Docs](https://docs.hetzner.com/cloud/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Terraform Documentation](https://www.terraform.io/docs)

## License

This project is provided as-is for self-hosting n8n.

n8n itself is licensed under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md).

