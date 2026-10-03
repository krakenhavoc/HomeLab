terraform {
  cloud {
    organization = "LabXPIO"

    workspaces {
      tags = ["wkjp"]
    }
  }
}
