# New app: add a line to local.apps.

locals {
  projects = {
    lab      = "Lab"
    dev      = "Dev"
    prd      = "Prd"
    platform = "Platform"
  }

  # app => tiers. Workspace is <app>-<tier>, or <app> when equal.
  apps = {
    lab            = ["lab"]
    plex           = ["dev", "prd"]
    nfs            = ["dev", "prd"]
    frontends      = ["prd"]
    lastdash       = ["prd"]
    "cmd-and-ctrl" = ["dev", "prd"]
  }

  # frontends/backend.tf still selects on "apps".
  extra_tags = {
    "frontends-prd" = ["apps"]
  }

  platform = {
    shared          = "shared"
    "GH-Controller" = "gh-runner"
    "GH-Worker"     = "gh-runner"
  }

  tiered = merge([
    for app, tiers in local.apps : {
      for tier in tiers : (app == tier ? app : "${app}-${tier}") => { app = app, project = tier }
    }
  ]...)

  workspaces = merge(
    {
      for key, ws in local.tiered : key => {
        name    = key
        project = ws.project
        tags = merge(
          { (ws.app) = "", env = ws.project },
          { for tag in lookup(local.extra_tags, key, []) : tag => "" },
        )
      }
    },
    {
      for key, app in local.platform : key => {
        name    = key
        project = "platform"
        tags    = { (app) = "", env = "platform" }
      }
    },
  )
}

resource "tfe_project" "tier" {
  for_each = local.projects

  name = each.value
}

resource "tfe_workspace" "this" {
  for_each = local.workspaces

  name       = each.value.name
  project_id = tfe_project.tier[each.value.project].id
  tags       = each.value.tags

  # CLI-driven; no VCS runs.
  file_triggers_enabled = false
  queue_all_runs        = false

  # Refuse to delete a workspace that still holds state.
  force_delete = false
}

resource "tfe_workspace_settings" "this" {
  for_each = local.workspaces

  workspace_id   = tfe_workspace.this[each.key].id
  execution_mode = "local"
}
