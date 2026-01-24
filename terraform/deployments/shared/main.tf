resource "proxmox_virtual_environment_download_file" "windows_11_iso" {
  count = var.win11_iso_url != "" ? 1 : 0

  node_name    = var.pve.host
  datastore_id = var.datastore_id
  content_type = "iso"

  url       = var.win11_iso_url
  file_name = local.win11_iso_name

  # This prevents Terraform from re-downloading if the file exists,
  # needed as URL will change but we don't want to re-download each time
  overwrite = false
}

resource "proxmox_virtual_environment_download_file" "virtio_drivers" {
  node_name    = var.pve.host
  datastore_id = "local"
  content_type = "iso"
  url          = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso"
  file_name    = "virtio-win.iso"
}

resource "proxmox_virtual_environment_download_file" "noble_lxc_img" {
  node_name    = var.pve.host
  content_type = "vztmpl"
  datastore_id = "local"
  url          = "https://mirrors.servercentral.com/ubuntu-cloud-images/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64-root.tar.xz"
  file_name    = "ubuntu-24.04-server-cloudimg-amd64-root.tar.xz"
}
