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
