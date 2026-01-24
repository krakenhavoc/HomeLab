locals {
  volume     = "/srv/storage/${var.nfs_server.env}/nfs"
  mount_path = "/export/nfs"
}
