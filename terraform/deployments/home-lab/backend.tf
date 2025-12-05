terraform {
  cloud {

    organization = "LabXPIO"

    workspaces {
      name = "HomeLab"
    }
  }
}
