resource "proxmox_virtual_environment_file" "gh_runner_cloudinit" {
  provider     = pve
  for_each     = local.instances
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/setup-gh-runner.yaml.tftpl", {
      gh_runner_admin_username = var.gh_runner.admin_username
      gh_registration_token    = var.gh_registration_token
      gh_runner_hostname       = each.value.name
      proxmox_host             = var.pve.host
      proxmox_private_key      = indent(4, var.proxmox_private_key)
      deployment_tag           = local.deployment_tag
      labels_flag              = local.deployment_tag == "gh-controller" ? "--labels self-hosted,linux,controller" : "--labels self-hosted,linux,worker"
    })
    file_name = "setup-${each.value.name}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "gh_runner" {
  provider = pve
  for_each = local.instances

  name        = each.value.name
  node_name   = var.pve.host
  description = "Managed by Terraform - ${each.value.role}"
  tags        = each.value.tags

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

  # Without this, adding one runner destroys and rebuilds every existing one.
  #
  # gh_registration_token is minted fresh on every workflow_dispatch and is
  # interpolated into EVERY instance's cloud-init. A new token therefore changes
  # source_raw.data on all of them; source_raw forces replacement of
  # proxmox_virtual_environment_file, which makes its id unknown at plan time,
  # which propagates into user_data_file_id here and forces the VM to be
  # replaced. Going from 2 workers to 3 rebuilt gunner-0 and gunner-1 as
  # collateral, killing whatever they were running.
  #
  # This is the same cascade that destroyed the production cmd_and_ctrl VM and
  # its data disk on 2026-09-10. Runners are stateless so the stakes are far
  # lower here, but it still cancels in-flight jobs and it is never what
  # "add a runner" is meant to do.
  #
  # Cloud-init is first-boot only, so a changed template is not a reason to
  # rebuild a running runner. The cost: a genuine template change (runner
  # version bump, new repo registration) no longer reaches existing VMs. Roll
  # those out deliberately with terraform-replace.yaml, one instance at a time:
  #
  #   gh workflow run terraform-replace.yaml \
  #     -f replace_resource='proxmox_virtual_environment_vm.gh_runner["0"]' \
  #     -f deployment_name=gh-runner -f environment=GH-Worker
  lifecycle {
    ignore_changes = [initialization]
  }
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
