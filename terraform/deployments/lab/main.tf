resource "proxmox_virtual_environment_file" "openclaw_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-openclaw.yaml.tftpl", {
      openclaw_hostname = var.openclaw.name_prefix
      admin_username    = var.openclaw.admin_username
    })
    file_name = "setup-${var.openclaw.name_prefix}.yaml"
  }
}

module "openclaw" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.3.0"

  vm_name                        = var.openclaw.name_prefix
  vm_node_name                   = var.pve.host
  vm_description                 = var.openclaw.description
  vm_tags                        = var.openclaw.tags
  vm_bios                        = var.openclaw.bios
  clone_vm_id                    = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
  vm_cpu_cores                   = var.openclaw.cpu_cores
  vm_memory_mb                   = var.openclaw.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.openclaw.disk_interface
  vm_disk_size                   = var.openclaw.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.openclaw_cloudinit.id
  vm_network_bridge              = var.openclaw.network_bridge
  vm_vlan_id                     = var.openclaw.vlan_id

  # --- Power state ----------------------------------------------------------
  # openclaw is powered off on purpose and is not meant to autostart. Both
  # values live in env/lab/terraform.tfvars; unset they would default to true,
  # which is what the provider assumes for any VM that does not say otherwise.
  #
  # That default is exactly what went wrong before these lines existed. With
  # the attributes unwritten every lab plan carried
  #   ~ on_boot = false -> true
  #   ~ started = false -> true
  # on openclaw, and the first apply after the Cloudflare outage was fixed
  # did start it. This is the change that stops that recurring.
  vm_started = var.openclaw.started
  vm_on_boot = var.openclaw.on_boot
}

# -----------------------------------------------------------------------------
# openclaw-2 — upstream install, Codex provider
# -----------------------------------------------------------------------------
# A second OpenClaw host that exists to try the upstream install path against
# the original. The `openclaw` VM above builds krakenhavoc/openclaw@fork from
# source on the box; this one runs https://openclaw.ai/install.sh, which is
# Node 24 plus `npm i -g openclaw@latest`. Different provider too: Codex
# (native app-server runtime, `openai/gpt-5.5`) rather than Azure Foundry.
#
# Like every other VM built from pm-cloudinit-vm, editing this snippet
# REPLACES THE VM. source_raw forces the file resource to be replaced, which
# makes its id unknown at plan time, which propagates into
# vm_cloudinit_user_data_file_id and rebuilds the guest -- the failure mode
# documented on the cmd_and_ctrl VM (deployments/cmd-and-ctrl). That resource works around it
# with `lifecycle { ignore_changes = [initialization] }`; a module call cannot,
# since lifecycle blocks are not inputs.
#
# For this box that is the intended trade, not a hazard to route around: it is
# a trial install, and rebuilding it from an edited snippet is the point. Just
# know that a rebuild discards the Codex OAuth login, which is a manual
# device-code step (see the template's final_message) and not reproducible
# from Terraform. CHECK THE PLAN before applying an unrelated change.

resource "proxmox_virtual_environment_file" "openclaw_2_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-openclaw-2.yaml.tftpl", {
      openclaw_hostname = var.openclaw_2.name_prefix
      admin_username    = var.openclaw_2.admin_username
    })
    file_name = "setup-${var.openclaw_2.name_prefix}.yaml"
  }
}

module "openclaw_2" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.3.0"

  vm_name                        = var.openclaw_2.name_prefix
  vm_node_name                   = var.pve.host
  vm_description                 = var.openclaw_2.description
  vm_tags                        = var.openclaw_2.tags
  vm_bios                        = var.openclaw_2.bios
  clone_vm_id                    = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
  vm_cpu_cores                   = var.openclaw_2.cpu_cores
  vm_memory_mb                   = var.openclaw_2.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.openclaw_2.disk_interface
  vm_disk_size                   = var.openclaw_2.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.openclaw_2_cloudinit.id
  vm_network_bridge              = var.openclaw_2.network_bridge
  vm_vlan_id                     = var.openclaw_2.vlan_id

  # --- Static addressing: NOW BLOCKED ONLY ON NETWORK FACTS -----------------
  # The module ref above is v0.3.0, so these five inputs EXIST and could be
  # uncommented today. They are not, because nobody has supplied the VLAN 200
  # facts they need, and those are facts about the physical network that
  # cannot be derived from inside this repo (see the checklist in
  # env/lab/terraform.tfvars).
  #
  # The old blocker is gone: v0.3.0 is tagged and pinned, so this is no longer
  # waiting on a release. Only on an address.
  #
  # Leaving them commented rather than passing them as null is still the right
  # call for a different reason -- it keeps the "what is missing" checklist
  # attached to the lines it blocks. Passing null would validate fine against
  # v0.3.0 and render DHCP exactly as today, but it would read as a decision
  # rather than an omission.
  #
  # A wrong guess here is not a failed plan; it is an IP conflict on a live
  # segment, which presents as intermittent packet loss on openclaw-2 AND on
  # whatever else holds the address, and neither symptom points at this file.
  #
  # vm_ipv4_address = var.openclaw_2.ipv4_address
  # vm_ipv4_gateway = var.openclaw_2.ipv4_gateway
  # vm_dns_servers  = var.openclaw_2.dns_servers
  # vm_dns_domain   = var.openclaw_2.dns_domain
  # vm_mac_address  = var.openclaw_2.mac_address
}

resource "proxmox_virtual_environment_file" "pwnbox_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-pwnbox.yaml.tftpl", {
      pwnbox_admin_username = var.pwnbox.admin_username
      pwnbox_hostname       = var.pwnbox.name_prefix
    })
    file_name = "setup-${var.pwnbox.name_prefix}.yaml"
  }
}

module "pwnbox" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.3.0"

  vm_name                        = var.pwnbox.name_prefix
  vm_node_name                   = var.pve.host
  vm_description                 = var.pwnbox.description
  vm_tags                        = var.pwnbox.tags
  vm_bios                        = var.pwnbox.bios
  clone_vm_id                    = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
  vm_cpu_cores                   = var.pwnbox.cpu_cores
  vm_memory_mb                   = var.pwnbox.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.pwnbox.disk_interface
  vm_disk_size                   = var.pwnbox.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.pwnbox_cloudinit.id
  vm_network_bridge              = var.pwnbox.network_bridge
  vm_vlan_id                     = var.pwnbox.vlan_id
}

# cmd_and_ctrl moved to deployments/cmd-and-ctrl (imported there). Forget, don't destroy.
removed {
  from = proxmox_virtual_environment_vm.cmd_and_ctrl
  lifecycle {
    destroy = false
  }
}

removed {
  from = proxmox_virtual_environment_file.cmd_and_ctrl_cloudinit
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_zero_trust_tunnel_cloudflared.cmd_and_ctrl_dev
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_zero_trust_tunnel_cloudflared_config.cmd_and_ctrl_dev
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_dns_record.cmd_and_ctrl_dev
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_r2_bucket.cmd_and_ctrl_backup
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_r2_bucket_lifecycle.cmd_and_ctrl_backup
  lifecycle {
    destroy = false
  }
}

# -----------------------------------------------------------------------------
# Windows 11 VM
# -----------------------------------------------------------------------------
# Uses a raw resource instead of the cloud-init module since Windows requires
# ISO-based installation with UEFI, TPM 2.0, and VirtIO driver loading.
# Post-apply steps:
#   1. Attach virtio-win.iso as a second CD-ROM via Proxmox UI (Hardware > Add > CD/DVD)
#   2. Boot the VM and install Windows via the Proxmox console
#   3. During disk selection, load driver: vioscsi\w11\amd64 from the VirtIO CD
#   4. After install, run virtio-win-gt-x64.msi from the VirtIO CD for all drivers + QEMU Guest Agent

resource "proxmox_virtual_environment_vm" "windows11" {
  provider = pve

  name        = var.windows11.name_prefix
  node_name   = var.pve.host
  description = var.windows11.description
  tags        = sort(concat(["terraform"], var.windows11.tags))
  on_boot     = false
  bios        = "ovmf"
  machine     = "q35"

  operating_system {
    type = "win11"
  }

  cpu {
    type    = "host"
    cores   = var.windows11.cpu_cores
    sockets = 1
    flags   = ["+nested-virt"]
  }

  memory {
    dedicated = var.windows11.memory_mb
    floating  = 0
  }

  tpm_state {
    version      = "v2.0"
    datastore_id = var.vm_disk_datastore_id
  }

  efi_disk {
    datastore_id      = var.vm_disk_datastore_id
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = true
  }

  # OS disk — VirtIO SCSI for best performance
  disk {
    interface    = "scsi0"
    datastore_id = var.vm_disk_datastore_id
    size         = var.windows11.os_disk_size
    file_format  = "raw"
    cache        = "writeback"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  scsi_hardware = "virtio-scsi-single"

  # Windows 11 installation ISO
  cdrom {
    file_id   = "local:iso/win11-latest.iso"
    interface = "ide0"
  }

  agent {
    enabled = true
    type    = "virtio"
    trim    = true
  }

  network_device {
    model   = "virtio"
    bridge  = var.windows11.network_bridge
    vlan_id = var.windows11.vlan_id
  }

  vga {
    type   = "virtio"
    memory = 64
  }

  stop_on_destroy = true
}
