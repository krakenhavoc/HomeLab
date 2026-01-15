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
