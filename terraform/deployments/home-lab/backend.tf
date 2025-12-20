terraform {
  cloud {

    organization = "LabXPIO"

    workspaces {
      tags = ["lab"]
    }
  }
}
