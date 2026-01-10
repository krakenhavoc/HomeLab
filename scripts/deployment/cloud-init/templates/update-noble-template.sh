#!/bin/bash
set -euo pipefail

VMID=9000
CODENAME=noble
STORAGE=ssd_1641G_thin
BRIDGE=vmbr0
IMAGE_URL=https://cloud-images.ubuntu.com/${CODENAME}/current/${CODENAME}-server-cloudimg-amd64.img
IMAGE_FILE=/tmp/${CODENAME}-cloudimg.img

echo "==> Downloading latest cloud image"
curl -L "${IMAGE_URL}" -o "${IMAGE_FILE}"

echo "==> Removing existing VM/template if it exists"
if qm status "${VMID}" &>/dev/null; then
  qm stop "${VMID}" || true
  qm destroy "${VMID}" --purge
fi

echo "==> Creating VM"
qm create "${VMID}" \
  --name "${CODENAME}-template" \
  --memory 2048 \
  --net0 virtio,bridge="${BRIDGE}" \
  --agent enabled=1 \
  --scsihw virtio-scsi-pci

echo "==> Importing disk"
qm importdisk "${VMID}" "${IMAGE_FILE}" "${STORAGE}"

echo "==> Attaching disk and cloud-init"
qm set "${VMID}" \
  --scsi0 "${STORAGE}":vm-"${VMID}"-disk-0 \
  --ide2 "${STORAGE}":cloudinit \
  --boot order=scsi0 \
  --serial0 socket \
  --vga serial0

echo "==> Converting VM to template"
qm template "${VMID}"

echo "==> Cleanup"
rm -f "${IMAGE_FILE}"

echo "==> Done"
