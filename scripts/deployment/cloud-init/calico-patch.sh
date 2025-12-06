#!/bin/bash
# calico-patch.sh
# This script downloads Calico, injects the correct CIDR, and applies the manifest.

# Ensure script execution stops on error
set -eo pipefail

echo "Starting Calico patch and installation..."

# 1. Define the manifest URL and download the file locally
CALICO_URL="https://docs.projectcalico.org/manifests/calico.yaml"
CALICO_FILE="/tmp/calico.yaml"

curl -fsSL "$CALICO_URL" -o "$CALICO_FILE"

# 2. Inject the CIDR config block using a HERE-DOC structure
# We ensure the indentation (8 spaces) is correct for the YAML structure.
echo "Inserting CALICO_IPV4POOL_CIDR 10.244.0.0/16..."
cat <<'CIDR_BLOCK' > /tmp/cidr-block-to-insert.txt
            - name: CALICO_IPV4POOL_CIDR
              value: "10.244.0.0/16"
CIDR_BLOCK

# Anchor on the line right after CALICO_IPV4POOL_IPIP value: "Always" and insert the block
sed -i '/value: "Always"/r /tmp/cidr-block-to-insert.txt' "$CALICO_FILE"

# 3. Clean up the original commented section (optional, but good practice)
echo "Cleaning up commented CIDR lines..."
sed -i '/^            # - name: CALICO_IPV4POOL_CIDR/,/^            #   value: "192.168.0.0\/16"/d' "$CALICO_FILE"

# 4. Apply the EDITED manifest
echo "Applying patched Calico manifest..."
kubectl apply --validate=false -f "$CALICO_FILE"

# 5. Clean up temporary files
rm /tmp/cidr-block-to-insert.txt
rm "$CALICO_FILE"

echo "Calico installation complete."
