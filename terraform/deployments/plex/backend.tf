terraform {
  cloud {

    organization = "LabXPIO"

    workspaces {
      tags = ["plex"]
    }
  }
}
