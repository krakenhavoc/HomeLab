module "k8s_controlplane" {
  source   = "../../modules/compute/pve-cloudinit-vm"
  for_each = toset([for i in range(var.k8s_controlplane.node_count) : tostring(i)])

  vm_name                         = "${var.k8s_controlplane.name_prefix}-${each.key}"
  memory_mb                       = var.k8s_controlplane.memory_mb
  ci_user_data                    = "vendor=local:snippets/setup_k8s_master.yml"
  cloudinit-example_root-password = var.cloudinit-example_root-password
}

module "k8s_workers" {
  source   = "../../modules/compute/pve-cloudinit-vm"
  for_each = toset([for i in range(var.k8s_worker.node_count) : tostring(i)])

  vm_name                         = "${var.k8s_worker.name_prefix}-${each.key}"
  memory_mb                       = var.k8s_worker.memory_mb
  ci_user_data                    = "vendor=local:snippets/setup_k8s_worker.yml"
  cloudinit-example_root-password = var.cloudinit-example_root-password
}
