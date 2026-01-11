terraform {
  cloud {

    organization = "LabXPIO"

    workspaces {
      name = "GH-Runner"
    }
  }
}
