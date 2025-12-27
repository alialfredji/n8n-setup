output "server_ip" {
  description = "Public IP address of the server"
  value       = hcloud_server.n8n.ipv4_address
}

output "server_name" {
  description = "Name of the server"
  value       = hcloud_server.n8n.name
}

output "domain" {
  description = "Domain configured for n8n"
  value       = var.domain
}

output "n8n_url" {
  description = "Full URL for n8n access"
  value       = "https://${var.domain}"
}

