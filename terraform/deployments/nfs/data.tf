data "proxmox_virtual_environment_file" "ubuntu_2404_lxc_img" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.pve.host
  file_name    = "ubuntu-24.04-server-cloudimg-amd64-root.tar.xz"
}
