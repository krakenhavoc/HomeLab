module "gh_runner" {
  source   = "../../modules/compute/pve-cloudinit-vm"
  for_each = toset([for i in range(var.gh_runner.node_count) : tostring(i)])

  vm_name                         = "${var.gh_runner.name_prefix}-${each.key}"
  cpu_cores                       = var.gh_runner.cpu_cores
  memory_mb                       = var.gh_runner.memory_mb
  clone_name                      = var.gh_runner.template
  ci_user_data                    = "vendor=snippets:snippets/setup-gh-runner.yaml"
  cloudinit-example_root-password = var.cloudinit-example_root-password
  os_disk_size                    = var.gh_runner.os_disk_size
  network_bridge                  = var.gh_runner.network_bridge
}
