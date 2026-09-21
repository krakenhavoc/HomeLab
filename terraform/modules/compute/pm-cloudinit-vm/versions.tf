terraform {
  # 1.9, not 1.0: vm_ipv4_gateway's validation refers to another variable
  # (vm_ipv4_address), and cross-variable references in a validation block are
  # a 1.9 feature. On anything older the module fails to load rather than
  # quietly skipping the check. Every deployment in this repo pins ~> 1.14.3,
  # so the floor is only a floor — it is documentation for anyone consuming
  # this module from outside the repo by git ref.
  required_version = ">= 1.9"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.93.0, < 1.0"
    }
  }
}
