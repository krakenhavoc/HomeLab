output "ipv4_address" {
  description = "The monitoring VM's LAN address (cmd_and_ctrl's CMDCTRL_MONITORING_URL host)"
  value       = local.ipv4_host
}

output "grafana_url" {
  description = "Grafana, LAN/VPN only"
  value       = "http://${local.ipv4_host}:3000"
}

output "prometheus_remote_write_url" {
  description = "Prometheus remote write through Caddy; basic auth prod/dev"
  value       = "http://${local.ipv4_host}:9091/api/v1/write"
}

output "loki_push_url" {
  description = "Loki push through Caddy; basic auth prod/dev"
  value       = "http://${local.ipv4_host}:3101/loki/api/v1/push"
}
