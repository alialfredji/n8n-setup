# SSH Key
resource "hcloud_ssh_key" "default" {
  name       = "${var.server_name}-key"
  public_key = var.ssh_public_key
}

# Firewall
resource "hcloud_firewall" "n8n" {
  name = "${var.server_name}-firewall"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

# Cloud-init configuration
locals {
  cloud_init = templatefile("${path.module}/cloud-init.yaml", {
    n8n_encryption_key      = var.n8n_encryption_key
    n8n_jwt_secret          = var.n8n_jwt_secret
    n8n_basic_auth_user     = var.n8n_basic_auth_user
    n8n_basic_auth_password = var.n8n_basic_auth_password
    postgres_db             = var.postgres_db
    postgres_user           = var.postgres_user
    postgres_password       = var.postgres_password
    domain                  = var.domain
  })
}

# Server
resource "hcloud_server" "n8n" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.server_location
  image       = var.server_image

  ssh_keys = [hcloud_ssh_key.default.id]

  firewall_ids = [hcloud_firewall.n8n.id]

  user_data = local.cloud_init

  labels = {
    type        = "n8n"
    environment = "production"
  }

  lifecycle {
    ignore_changes = [
      user_data,
      ssh_keys
    ]
  }
}

# Cloudflare DNS Record
resource "cloudflare_record" "n8n" {
  zone_id = var.cloudflare_zone_id
  name    = split(".", var.domain)[0]
  content = hcloud_server.n8n.ipv4_address
  type    = "A"
  ttl     = 1
  proxied = false
}

