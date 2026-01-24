locals {
  docker_compose = templatefile("${path.module}/templates/docker-compose.yaml.tftpl", {
    release_tag       = var.plex_release_tag
    volume_mount_path = local.volume_mount_path
  })
  volume_mount_path = "/home/plex/media"

}
