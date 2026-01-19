terraform {
  cloud {
    organization = "LabXPIO"

    workspaces {
      name = "lab"
    }
  }
}
