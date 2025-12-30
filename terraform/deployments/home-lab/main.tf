module "k8s_controlplane" {
  source   = "../../modules/compute/pve-cloudinit-vm"
  for_each = toset([for i in range(var.k8s_controlplane.node_count) : tostring(i)])

  vm_name                         = "${var.k8s_controlplane.name_prefix}-${each.key}"
  memory_mb                       = var.k8s_controlplane.memory_mb
  ci_user_data                    = "vendor=local:kubernetes/setup-k8s-master.yaml"
  cloudinit-example_root-password = var.cloudinit-example_root-password
  os_disk_size                    = var.k8s_controlplane.os_disk_size
  network_bridge                  = var.k8s_controlplane.network_bridge
}

module "k8s_workers" {
  source   = "../../modules/compute/pve-cloudinit-vm"
  for_each = toset([for i in range(var.k8s_worker.node_count) : tostring(i)])

  vm_name                         = "${var.k8s_worker.name_prefix}-${each.key}"
  memory_mb                       = var.k8s_worker.memory_mb
  ci_user_data                    = "vendor=local:kubernetes/setup-k8s-worker.yaml"
  cloudinit-example_root-password = var.cloudinit-example_root-password
  os_disk_size                    = var.k8s_worker.os_disk_size
  network_bridge                  = var.k8s_worker.network_bridge
}
