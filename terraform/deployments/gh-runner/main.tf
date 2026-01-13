resource "proxmox_virtual_environment_file" "gh_runner_cloudinit" {
  provider     = pve
  for_each     = toset([for i in range(var.instance_count) : tostring(i)])
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/setup-gh-runner.yaml.tftpl", {
      gh_runner_admin_username = var.gh_runner.admin_username
      gh_registration_token    = var.gh_registration_token
      gh_runner_hostname       = "${var.gh_runner.name_prefix}-${each.key}"
      admin_password           = var.admin_password
    })
    file_name = "setup-${var.gh_runner.name_prefix}-${each.key}.yaml"
  }
}

# module "gh_runner" {
#   source   = "../../modules/compute/pve-cloudinit-vm"
#   for_each = toset([for i in range(var.node_count) : tostring(i)])

#   vm_name                         = "${var.gh_runner.name_prefix}-${each.key}"
#   cpu_cores                       = var.gh_runner.cpu_cores
#   memory_mb                       = var.gh_runner.memory_mb
#   clone_name                      = var.gh_runner.template
#   cloudinit-example_root-password = var.cloudinit-example_root-password
#   os_disk_size                    = var.gh_runner.os_disk_size
#   network_bridge                  = var.gh_runner.network_bridge
#   ci_user_data                    = "user=local:snippets/setup-gh-runner.yaml"

#   depends_on = [proxmox_virtual_environment_file.gh_runner_cloudinit]
# }

resource "proxmox_virtual_environment_vm" "gh_runner" {
  provider = pve
  for_each = toset([for i in range(var.instance_count) : tostring(i)])

  name        = "${var.gh_runner.name_prefix}-${each.key}"
  node_name   = var.pve.host
  description = "Managed by Terraform"
  tags        = ["terraform", "ubuntu"]

  # 1. Matching your module's BIOS setting
  bios = "ovmf"

  clone {
    vm_id = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
    full  = true
  }

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = var.gh_runner.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.gh_runner.memory_mb
  }

  # 2. Add the Disk block (to replace the disks block in your module)
  disk {
    datastore_id = "ssd_1641G_thin"
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.gh_runner.os_disk_size
  }

  initialization {
    datastore_id = "ssd_1641G_thin" # This is where the cloud-init ISO is generated
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    # BPG uses the internal file ID format automatically
    user_data_file_id = proxmox_virtual_environment_file.gh_runner_cloudinit[each.key].id
  }

  network_device {
    bridge = var.gh_runner.network_bridge
  }

  # 3. Serial device (required by most cloud-init images for display)
  serial_device {}

  vga {
    type = "std"
  }

  operating_system {
    type = "l26"
  }

  # explicit depends_on removed — `user_data_file_id` creates an implicit dependency
}

# output "vm_ipv4_address" {
#   value = proxmox_virtual_environment_vm.gh_runner[each.key].ipv4_addresses[1][0]
# }

# resource "null_resource" "wait_cloudinit" {
#   for_each = proxmox_virtual_environment_vm.gh_runner
#   depends_on = [proxmox_virtual_environment_vm.gh_runner]

#   connection {
#     type     = "ssh"
#     host     = each.value.ipv4_addresses[0][0]
#     user     = "root"
#     password = var.cloudinit-example_root-password
#     timeout  = "5m"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "echo 'waiting for cloud-init sentinel...'",
#       "for i in $(seq 1 120); do if [ -f /var/lib/cloud/instance/boot-finished ]; then echo done; exit 0; fi; sleep 2; done; echo 'timeout waiting for cloud-init' >&2; exit 1"
#     ]
#   }
# }
