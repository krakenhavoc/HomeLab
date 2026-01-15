locals {
  docker_compose = templatefile("${path.module}/templates/docker-compose.yaml.tftpl", {
    release_tag = var.plex_release_tag
  })
}
