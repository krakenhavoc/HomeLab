terraform {
  cloud {
    organization = "LabXPIO"

    workspaces {
      tags = ["cmd-and-ctrl"]
    }
  }
}
