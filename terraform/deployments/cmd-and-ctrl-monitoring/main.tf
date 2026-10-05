# cmd_and_ctrl monitoring VM (cmd_and_ctrl ADR 0123 §6): Prometheus, Loki,
# Alertmanager, Grafana, blackbox_exporter, Caddy and Alloy in one compose
# project. LAN only: no Cloudflare tunnel and no DNS record (ADR decision 6).
#
# The VM is the only thing here. The stack is cmd-and-ctrl-monitoring/ in this
# repo, reconciled on the host by monitoring-sync; the alert rules and
# dashboards come from krakenhavoc/cmd_and_ctrl deploy/monitoring/ through
# cmdctrl-config-sync.
#
# Not backed up (ADR 0123 §6): every Grafana object that matters is
# provisioned from files, so a rebuild loses only metric and log history.

locals {
  # The address without its prefix, for the banner and the outputs.
  ipv4_host = split("/", var.monitoring.ipv4_address)[0]
}

resource "proxmox_virtual_environment_file" "cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-cmd-and-ctrl-monitoring.yaml.tftpl", {
      hostname       = var.monitoring.name_prefix
      admin_username = var.monitoring.admin_username
      ipv4_address   = var.monitoring.ipv4_address
      ipv4_host      = local.ipv4_host
      lan_cidrs      = var.monitoring.lan_cidrs

      grafana_admin_password = var.cmdctrl_monitoring_grafana_admin_password
      discord_webhook_url    = var.cmdctrl_monitoring_discord_webhook_url
      push_hash_prod         = var.cmdctrl_monitoring_push_hash_prod
      push_hash_dev          = var.cmdctrl_monitoring_push_hash_dev
      heartbeat_token        = var.cmdctrl_monitoring_heartbeat_token
    })
    file_name = "setup-${var.monitoring.name_prefix}.yaml"
  }
}

# Raw resource, not pm-cloudinit-vm: it needs a data disk and the lifecycle
# block below, which a module call can't take. Shaped like the cmd_and_ctrl
# VMs in deployments/cmd-and-ctrl.
resource "proxmox_virtual_environment_vm" "this" {
  provider = pve

  name        = var.monitoring.name_prefix
  node_name   = var.pve.host
  description = var.monitoring.description
  tags        = sort(concat(["terraform"], var.monitoring.tags))
  bios        = var.monitoring.bios
  machine     = "q35"

  efi_disk {
    datastore_id      = var.vm_disk_datastore_id
    file_format       = "raw"
    type              = "2m"
    pre_enrolled_keys = false
  }

  clone {
    vm_id = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
    full  = true
  }

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = var.monitoring.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.monitoring.memory_mb
  }

  # OS disk, cloned from the template. Docker's images and logs live here.
  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.monitoring.os_disk_size
  }

  # The stores (Prometheus 1 y / 60 GB cap, Loki 30 d, Grafana, Alertmanager),
  # mounted at /var/lib/monitoring.
  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = "virtio1"
    iothread     = true
    discard      = "on"
    size         = var.monitoring.data_disk_size
    file_format  = "raw"
  }

  initialization {
    datastore_id = var.vm_cloudinit_datastore_id
    ip_config {
      ipv4 {
        address = var.monitoring.ipv4_address
        gateway = var.monitoring.ipv4_gateway
      }
    }
    dns {
      servers = var.monitoring.dns_servers
      domain  = var.monitoring.dns_domain
    }
    user_data_file_id = proxmox_virtual_environment_file.cloudinit.id
  }

  network_device {
    bridge      = var.monitoring.network_bridge
    vlan_id     = var.monitoring.vlan_id
    mac_address = var.monitoring.mac_address
  }

  serial_device {}

  vga {
    type = "std"
  }

  operating_system {
    type = "l26"
  }

  # A snippet change replaces the file, whose id is then unknown at plan time,
  # which would replace the VM and its data disk (how the cmd_and_ctrl VM was
  # lost on 2026-09-10). So cloud-init is first-boot only: template, secret
  # and address edits reach a rebuilt host only. Stack changes go through
  # monitoring-sync instead. To rebuild on purpose, drop prevent_destroy first.
  lifecycle {
    ignore_changes  = [initialization]
    prevent_destroy = true
  }
}
