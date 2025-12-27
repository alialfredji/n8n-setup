# Command Reference

Complete command reference for managing your n8n infrastructure.

## Setup Commands

### Initial Configuration
```bash
# Validate project structure
./scripts/validate.sh

# Generate secrets
openssl rand -hex 32      # Encryption keys
openssl rand -base64 32   # Passwords

# Configure environments
cp .env.example .env
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

## Local Development

### Start/Stop
```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# Stop and remove volumes (DESTRUCTIVE)
docker compose down -v
```

### Monitoring
```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f n8n
docker compose logs -f postgres

# Check service status
docker compose ps

# Execute command in container
docker compose exec n8n sh
docker compose exec postgres psql -U n8n -d n8n
```

### Maintenance
```bash
# Restart services
docker compose restart

# Restart specific service
docker compose restart n8n

# Update images
docker compose pull
docker compose up -d

# View resource usage
docker stats
```

## Terraform (Infrastructure)

### Initialization
```bash
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format files
terraform fmt
```

### Planning
```bash
# Preview changes
terraform plan

# Save plan to file
terraform plan -out=tfplan

# Show current state
terraform show
```

### Deployment
```bash
# Apply changes
terraform apply

# Apply saved plan
terraform apply tfplan

# Apply without confirmation (use with caution)
terraform apply -auto-approve
```

### Inspection
```bash
# Show outputs
terraform output

# Show specific output
terraform output server_ip
terraform output -raw server_ip

# List resources
terraform state list

# Show resource details
terraform state show hcloud_server.n8n
```

### Destruction
```bash
# Destroy infrastructure (DESTRUCTIVE)
terraform destroy

# Destroy specific resource
terraform destroy -target=hcloud_server.n8n

# Destroy without confirmation (DANGEROUS)
terraform destroy -auto-approve
```

## Production Server Management

### Connection
```bash
# Get server IP
export SERVER_IP=$(cd terraform && terraform output -raw server_ip)

# SSH to server
ssh root@$SERVER_IP

# SSH with specific key
ssh -i ~/.ssh/your_key root@$SERVER_IP

# Copy file to server
scp file.txt root@$SERVER_IP:/root/

# Copy file from server
scp root@$SERVER_IP:/root/file.txt ./
```

### Docker Management (on server)
```bash
# After SSH to server:

# View running containers
docker ps

# View all containers
docker ps -a

# View logs
docker compose logs -f

# Check status
docker compose ps

# Restart services
docker compose restart

# Stop services
docker compose down

# Start services
docker compose up -d

# Update containers
docker compose pull
docker compose up -d
```

### Backup Operations
```bash
# Manual backup
/root/backup.sh

# List backups
ls -lh /root/backups/

# View backup cron job
crontab -l

# Check backup logs
tail -f /var/log/n8n-backup.log

# Download backup to local machine
scp root@$SERVER_IP:/root/backups/n8n_backup_*.sql.gz ./
```

### Restore Operations
```bash
# On server, after SSH:

# Stop n8n
docker compose stop n8n

# Restore database
zcat /root/backups/n8n_backup_YYYYMMDD_HHMMSS.sql.gz | \
  docker exec -i n8n_postgres psql -U n8n -d n8n

# Restore n8n data volume
docker run --rm \
  -v n8n_data:/data \
  -v /root/backups:/backup \
  alpine tar xzf /backup/n8n_data_YYYYMMDD_HHMMSS.tar.gz -C /data

# Start n8n
docker compose start n8n
```

### System Monitoring
```bash
# System resources
htop          # Interactive process viewer
df -h         # Disk usage
free -h       # Memory usage
uptime        # System uptime

# Docker resources
docker stats  # Container resource usage

# Network
netstat -tulpn         # Active connections
ss -tulpn              # Socket statistics

# Logs
tail -f /var/log/syslog           # System logs
tail -f /var/log/auth.log         # Authentication logs
tail -f /var/log/fail2ban.log     # Fail2ban logs

# Service status
systemctl status docker
systemctl status fail2ban
```

### Security Checks
```bash
# Check firewall status
ufw status verbose

# Check SSH configuration
cat /etc/ssh/sshd_config | grep PasswordAuthentication

# Check fail2ban status
fail2ban-client status
fail2ban-client status sshd

# View banned IPs
fail2ban-client get sshd banip

# Check for updates
apt update
apt list --upgradable

# View login history
last -n 20
lastb -n 20  # Failed logins
```

### SSL/TLS Management
```bash
# Caddy manages SSL automatically, but to check:

# View Caddy logs
docker compose logs caddy

# Force certificate renewal (rarely needed)
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# Check certificate expiry
echo | openssl s_client -servername n8n.yourdomain.com \
  -connect n8n.yourdomain.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

## Database Management

### PostgreSQL Commands
```bash
# Access PostgreSQL CLI
docker compose exec postgres psql -U n8n -d n8n

# PostgreSQL commands (once inside psql):
\dt              # List tables
\d+ tablename    # Describe table
\l               # List databases
\du              # List users
\q               # Quit

# Backup database
docker exec n8n_postgres pg_dump -U n8n n8n | gzip > backup.sql.gz

# Restore database
zcat backup.sql.gz | docker exec -i n8n_postgres psql -U n8n -d n8n

# Check database size
docker compose exec postgres psql -U n8n -d n8n -c \
  "SELECT pg_size_pretty(pg_database_size('n8n'));"
```

## n8n Specific

### Configuration
```bash
# View n8n environment variables
docker compose exec n8n env | grep N8N

# Restart n8n
docker compose restart n8n

# View n8n version
docker compose exec n8n n8n --version
```

### Troubleshooting
```bash
# Check n8n logs for errors
docker compose logs n8n | grep -i error

# Check if n8n can connect to database
docker compose exec n8n nc -zv postgres 5432

# Verify n8n data directory
docker compose exec n8n ls -la /home/node/.n8n
```

## Deployment Script

### Full Deployment
```bash
# Run full deployment
./scripts/deploy.sh
```

### Manual Deployment Steps
```bash
# Step by step deployment:

# 1. Initialize
cd terraform && terraform init

# 2. Validate
terraform validate

# 3. Plan
terraform plan -out=tfplan

# 4. Apply
terraform apply tfplan

# 5. Get server IP
export SERVER_IP=$(terraform output -raw server_ip)

# 6. Wait for server
while ! ssh -o ConnectTimeout=5 root@$SERVER_IP "echo ready" 2>/dev/null; do
    echo "Waiting for server..."
    sleep 10
done

# 7. Wait for cloud-init
ssh root@$SERVER_IP "cloud-init status --wait"

# 8. Verify deployment
ssh root@$SERVER_IP "docker ps"
```

## Cleanup Commands

### Remove Local Environment
```bash
# Stop and remove containers
docker compose down

# Remove volumes (DELETES DATA)
docker compose down -v

# Remove images
docker rmi postgres:17-alpine docker.n8n.io/n8nio/n8n:latest
```

### Destroy Infrastructure
```bash
# Destroy everything (DANGEROUS)
cd terraform
terraform destroy

# This will:
# - Delete the Hetzner server
# - Remove DNS records
# - Delete all data on server
# - Keep Terraform state locally
```

## Quick Troubleshooting

### Service Won't Start
```bash
# Check logs
docker compose logs servicename

# Check if port is already in use
lsof -i :5678

# Restart Docker daemon
sudo systemctl restart docker
```

### Connection Issues
```bash
# Test DNS resolution
dig n8n.yourdomain.com

# Test connectivity
curl -I https://n8n.yourdomain.com

# Check firewall
ufw status
```

### Performance Issues
```bash
# Check resource usage
docker stats

# Check disk space
df -h

# Check database size
docker compose exec postgres psql -U n8n -d n8n -c \
  "SELECT pg_size_pretty(pg_database_size('n8n'));"
```

## Emergency Procedures

### Complete Service Restart
```bash
ssh root@$SERVER_IP
cd /root
docker compose down
docker compose up -d
docker compose logs -f
```

### Rollback Update
```bash
# If update fails:
ssh root@$SERVER_IP
cd /root

# Pull specific version
docker pull docker.n8n.io/n8nio/n8n:1.XX.X

# Update docker-compose.yml to use specific version
nano docker-compose.yml
# Change: image: docker.n8n.io/n8nio/n8n:latest
# To:     image: docker.n8n.io/n8nio/n8n:1.XX.X

# Restart
docker compose up -d
```

### Recover from Backup
```bash
# See "Restore Operations" section above
```

---

**Tip**: Save this file locally and keep it accessible for quick reference!

