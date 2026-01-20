resource "proxmox_virtual_environment_download_file" "windows_11_iso" {
  node_name    = var.pve.host
  datastore_id = var.datastore_id
  content_type = "iso"

  # Accesses the "url" key from the Python JSON output
  url       = data.external.win11_iso.result.url
  file_name = local.win11_iso_name

  # This prevents Terraform from re-downloading if the file exists,
  # needed as URL will change but we don't want to re-download each time
  overwrite = false
}
