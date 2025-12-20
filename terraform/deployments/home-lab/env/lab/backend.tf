# tflint-ignore: terraform_required_version
terraform {
  cloud {

    organization = "LabXPIO"

    workspaces {
      name = "lab"
    }
  }
}
