terraform {
  cloud {
    organization = "LabXPIO"

    # Bootstrapped by hand; not self-managed.
    workspaces {
      name = "tfc"
    }
  }
}
