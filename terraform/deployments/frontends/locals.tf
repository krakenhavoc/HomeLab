locals {
  docker_compose = templatefile("${path.module}/templates/docker-compose.yaml.tftpl", {
    release_tag = var.redlib_release_tag
  })
  redlib_env = templatefile("${path.module}/templates/redlib-env.tftpl", {})
}
