module "k8s_master" {
  source = "../../modules/compute/pve-cloudinit-vm"

  vm_name                         = "k8s-master-0"
  memory_bytes                    = 4096
  ci_user_data                    = "vendor=local:snippets/setup_k8s_master.yml"
  cloudinit-example_root-password = var.cloudinit-example_root-password
}

module "k8s_workers" {
  source   = "../../modules/compute/pve-cloudinit-vm"
  for_each = toset(["0", "1"])

  vm_name                         = "k8s-worker-${each.key}"
  memory_bytes                    = 4096
  ci_user_data                    = "vendor=local:snippets/setup_k8s_worker.yml"
  cloudinit-example_root-password = var.cloudinit-example_root-password
}
