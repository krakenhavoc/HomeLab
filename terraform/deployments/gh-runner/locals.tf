locals {
  # Detect deployment type (gh-controller or gh-worker)
  # Prefer explicit var.deployment_tag, fallback to TF workspace, then default gh-worker
  deployment_tag = coalesce(
    var.deployment_tag,
    lower(terraform.workspace),
    "gh-worker"
  )
  is_controller = local.deployment_tag == "gh-controller"

  # Instance naming and tagging based on deployment type
  instances = {
    for i in range(var.instance_count) : tostring(i) => {
      name = local.is_controller ? "${var.gh_runner.name_prefix}-controller" : "${var.gh_runner.name_prefix}-${i}"
      tags = local.is_controller ? ["terraform", "controller", "gh-runner"] : ["terraform", "worker", "gh-runner"]
      role = local.is_controller ? "controller" : "worker"
    }
  }
}
