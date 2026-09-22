terraform {
  cloud {
    organization = "LabXPIO"

    # Pinned by name, like lab/. terraform-ci sets TF_WORKSPACE to the
    # GitHub environment name, which is also "lastdash-prod", so the two agree.
    workspaces {
      name = "lastdash-prod"
    }
  }
}
