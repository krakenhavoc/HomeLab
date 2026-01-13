terraform {
  cloud {
    organization = "LabXPIO"

    workspaces {
      # Use tags to manage multiple deployment types
      # Set TF_WORKSPACE=GH-Controller or TF_WORKSPACE=GH-Worker
      # Or use: terraform workspace select GH-Controller
      tags = ["gh-runner"]
    }
  }
}
