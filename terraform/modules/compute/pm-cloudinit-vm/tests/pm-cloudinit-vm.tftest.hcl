# Mock provider configuration for testing
mock_provider "proxmox" {}

# Test valid configuration with all required variables
run "valid_minimal_config" {
  command = plan

  variables {
    vm_name                        = "test-vm"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.name == "test-vm"
    error_message = "VM name should be test-vm"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.cpu[0].cores == 2
    error_message = "CPU cores should be 2"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.memory[0].dedicated == 2048
    error_message = "Memory should be 2048 MB"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.bios == "ovmf"
    error_message = "Default BIOS should be ovmf"
  }
}

# Test with VLAN configured
run "valid_with_vlan" {
  command = plan

  variables {
    vm_name                        = "test-vm-vlan"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM with VLAN"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
    vm_vlan_id                     = 100
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.network_device[0].vlan_id == 100
    error_message = "VLAN ID should be set to 100"
  }
}

# Test without VLAN configured
run "valid_without_vlan" {
  command = plan

  variables {
    vm_name                        = "test-vm-no-vlan"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM without VLAN"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
    # vm_vlan_id omitted
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.network_device[0].vlan_id == null
    error_message = "VLAN ID should be null when not configured"
  }
}

# Test with custom BIOS setting
run "valid_seabios_config" {
  command = plan

  variables {
    vm_name                        = "test-vm-seabios"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM with SeaBIOS"
    vm_bios                        = "seabios"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 4
    vm_memory_mb                   = 4096
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 50
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.bios == "seabios"
    error_message = "BIOS should be seabios"
  }
}

# Test with custom tags
run "valid_with_tags" {
  command = plan

  variables {
    vm_name                        = "test-vm-tagged"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM with tags"
    vm_tags                        = ["production", "web-server"]
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.this.tags) == 2
    error_message = "Should have 2 tags"
  }
}

# Test with disabled agent
run "valid_agent_disabled" {
  command = plan

  variables {
    vm_name                        = "test-vm-no-agent"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM without agent"
    vm_agent_enabled               = false
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.agent[0].enabled == false
    error_message = "Agent should be disabled"
  }
}

# Test with custom disk interface
run "valid_scsi_interface" {
  command = plan

  variables {
    vm_name                        = "test-vm-scsi"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM with SCSI"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_interface              = "scsi0"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].interface == "scsi0"
    error_message = "Disk interface should be scsi0"
  }
}

# Test invalid BIOS value
run "invalid_bios" {
  command = plan

  variables {
    vm_name                        = "test-vm-invalid"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM with invalid BIOS"
    vm_bios                        = "uefi"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
  }

  expect_failures = [
    var.vm_bios,
  ]
}

# -----------------------------------------------------------------------------
# Static addressing
# -----------------------------------------------------------------------------
# The first run below is the one that matters most. Every VM built from this
# module before static addressing existed rendered exactly `address = "dhcp"`,
# no gateway, no dns block. If that ever changes, openclaw, openclaw-2, pwnbox,
# redlib and plex all get a diff on `initialization` — which rewrites the
# cloud-init drive and reboots the guest. This run is the tripwire.

run "default_addressing_is_dhcp" {
  command = plan

  variables {
    vm_name                        = "test-vm-dhcp"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM on DHCP (the pre-existing default)"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
    # vm_ipv4_address, vm_ipv4_gateway, vm_dns_servers, vm_dns_domain and
    # vm_mac_address all omitted — that is the whole point of this run.
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.initialization[0].ip_config[0].ipv4[0].address == "dhcp"
    error_message = "With no static address the guest must stay on DHCP, exactly as it did before vm_ipv4_address existed."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.initialization[0].ip_config[0].ipv4[0].gateway == null
    error_message = "An unset gateway must render as an absent attribute, not an empty string — anything else is a diff on every existing consumer."
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.this.initialization[0].dns) == 0
    error_message = "With no DNS inputs the dns block must not be rendered at all; an empty dns block tells the guest it has no resolvers."
  }
}

# Only a search domain, no servers. Asserts the OR in the dynamic's for_each:
# a domain on top of DHCP-supplied resolvers is a legitimate configuration, and
# `servers` must stay absent so the lease's resolvers survive.
run "dns_domain_only" {
  command = plan

  variables {
    vm_name                        = "test-vm-dns-domain"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM with a search domain over DHCP resolvers"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
    vm_dns_domain                  = "labxp.io"
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.this.initialization[0].dns) == 1
    error_message = "A search domain on its own must still render a dns block."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.initialization[0].dns[0].servers == null
    error_message = "With no servers supplied the servers attribute must be absent, not an empty list — an empty list would clobber the DHCP-supplied resolvers."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.initialization[0].dns[0].domain == "labxp.io"
    error_message = "DNS search domain should be labxp.io"
  }
}

# The full static path: address, gateway, both resolvers, search domain, pinned
# MAC. This is the shape openclaw-2 is wired for.
run "valid_static_addressing" {
  command = plan

  variables {
    vm_name                        = "test-vm-static"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM with static addressing"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
    vm_vlan_id                     = 200
    vm_ipv4_address                = "192.168.200.40/24"
    vm_ipv4_gateway                = "192.168.200.1"
    vm_dns_servers                 = ["192.168.200.2", "192.168.200.3"]
    vm_dns_domain                  = "labxp.io"
    vm_mac_address                 = "BC:24:11:00:02:40"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.initialization[0].ip_config[0].ipv4[0].address == "192.168.200.40/24"
    error_message = "Static address should be passed through in CIDR form"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.initialization[0].ip_config[0].ipv4[0].gateway == "192.168.200.1"
    error_message = "Gateway should be set alongside the static address"
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.this.initialization[0].dns) == 1
    error_message = "A dns block should be rendered when servers are supplied"
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.this.initialization[0].dns[0].servers) == 2
    error_message = "Both DNS servers should reach the guest"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.network_device[0].mac_address == "BC:24:11:00:02:40"
    error_message = "A pinned MAC should be passed through to the network device"
  }
}

# A gateway with no address is not a partial configuration, it is a silent
# no-op: the guest comes up on DHCP and the declared gateway is discarded.
# Catch it at plan time.
run "invalid_gateway_without_address" {
  command = plan

  variables {
    vm_name                        = "test-vm-orphan-gw"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM with a gateway and no static address"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
    vm_ipv4_gateway                = "192.168.200.1"
  }

  expect_failures = [
    var.vm_ipv4_gateway,
  ]
}

# A bare address with no prefix length is the mistake that costs a rebuild: the
# VM boots with no network and only the Proxmox console to fix it from.
run "invalid_address_without_prefix" {
  command = plan

  variables {
    vm_name                        = "test-vm-bare-addr"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM with a non-CIDR static address"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
    vm_ipv4_address                = "192.168.200.40"
  }

  expect_failures = [
    var.vm_ipv4_address,
  ]
}

# The paste-the-CIDR-into-both-fields mistake.
run "invalid_gateway_with_prefix" {
  command = plan

  variables {
    vm_name                        = "test-vm-cidr-gw"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM with a gateway carrying a prefix length"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
    vm_ipv4_address                = "192.168.200.40/24"
    vm_ipv4_gateway                = "192.168.200.1/24"
  }

  expect_failures = [
    var.vm_ipv4_gateway,
  ]
}

run "invalid_mac_address" {
  command = plan

  variables {
    vm_name                        = "test-vm-bad-mac"
    vm_node_name                   = "pve-node1"
    vm_description                 = "Test VM with a malformed MAC"
    clone_vm_id                    = 9000
    vm_cpu_cores                   = 2
    vm_memory_mb                   = 2048
    vm_disk_datastore_id           = "local-lvm"
    vm_disk_size                   = 20
    vm_cloudinit_datastore_id      = "local"
    vm_cloudinit_user_data_file_id = "local:snippets/user-data.yml"
    vm_network_bridge              = "vmbr0"
    vm_mac_address                 = "BC-24-11-00-02-40"
  }

  expect_failures = [
    var.vm_mac_address,
  ]
}
