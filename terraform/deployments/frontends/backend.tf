terraform {
  cloud {

    organization = "LabXPIO"

    workspaces {
      tags = ["apps"]
    }
  }
}
