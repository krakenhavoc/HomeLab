# One-time adoption of pre-existing projects/workspaces. Delete after apply.

locals {
  existing_projects = {
    lab      = "prj-7ZKg2XkPSEf4oh4k"
    platform = "prj-BhDbTCuQ2Aw5qrf2" # was "HomeLab"
  }

  existing_workspaces = {
    lab                = "ws-fBM6a5NLekB8Fz5g"
    "plex-dev"         = "ws-TNF4agqkdbndGcd6"
    "plex-prd"         = "ws-UAFHvuuhhB2qJJwi"
    "nfs-dev"          = "ws-3tp1benb6ZFAdjjj"
    "nfs-prd"          = "ws-ERRM15YroX7uq2X7"
    "frontends-prd"    = "ws-AuAni5uuyeufKxrG"
    "lastdash-prd"     = "ws-oVSKXQRTPV2mZHeB"
    "cmd-and-ctrl-dev" = "ws-LgcKsg99Lif2uGdv"
    "cmd-and-ctrl-prd" = "ws-oKFtuYQ4Ps8u96od"
    shared             = "ws-qirYeD6rqADK4e2J"
    "GH-Controller"    = "ws-xQqi8RnKiRWDGLbR"
    "GH-Worker"        = "ws-csz8yxJY47J4Bhof"
  }
}

import {
  for_each = local.existing_projects
  to       = tfe_project.tier[each.key]
  id       = each.value
}

import {
  for_each = local.existing_workspaces
  to       = tfe_workspace.this[each.key]
  id       = each.value
}

import {
  for_each = local.existing_workspaces
  to       = tfe_workspace_settings.this[each.key]
  id       = each.value
}
