terraform {
  cloud {

    organization = "LabXPIO"

    workspaces {
      tags = ["shared"]
    }
  }
}
