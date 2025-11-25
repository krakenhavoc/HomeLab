#!/usr/bin/env bash

# Usage: ./install.sh [<terraform-version>]

set -euo pipefail
IFS=$'\n\t'

TERRAFORM_VERSION="${1:-}" # optional version (example: 1.5.7)

KEYRING_PATH="/usr/share/keyrings/hashicorp-archive-keyring.gpg"
REPO_PATH="/etc/apt/sources.list.d/hashicorp.list"

err() { printf "%s\n" "$*" >&2; }
run() { echo "+ $*"; "$@"; }

if ! command -v apt-get >/dev/null 2>&1; then
	err "This installer targets Debian/Ubuntu systems using apt. Exiting."
	exit 64
fi

if [ "$EUID" -ne 0 ]; then
	SUDO="sudo"
else
	SUDO=""
fi

# Ensure required tools are available
if ! command -v gpg >/dev/null 2>&1; then
	run $SUDO apt-get update
	run $SUDO apt-get install -y gnupg
fi
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
	run $SUDO apt-get update
	run $SUDO apt-get install -y curl
fi

# Fetch HashiCorp GPG key and write keyring
fetch_gpg() {
	tmpfile=$(mktemp)
	trap 'rm -f "$tmpfile"' RETURN

	if command -v curl >/dev/null 2>&1; then
		curl -fsSL https://apt.releases.hashicorp.com/gpg -o "$tmpfile"
	else
		wget -qO "$tmpfile" https://apt.releases.hashicorp.com/gpg
	fi

	run $SUDO gpg --dearmor -o "$KEYRING_PATH" < "$tmpfile"
}

# Add apt source if not present
add_repo() {
	arch=$(dpkg --print-architecture)
	codename=""
	if [ -r /etc/os-release ]; then
		codename=$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || true)
	fi
	if [ -z "$codename" ] && command -v lsb_release >/dev/null 2>&1; then
		codename=$(lsb_release -cs)
	fi
	if [ -z "$codename" ]; then
		err "Could not determine distribution codename (e.g. 'focal', 'jammy'). Aborting."
		exit 64
	fi

	line="deb [arch=${arch} signed-by=${KEYRING_PATH}] https://apt.releases.hashicorp.com ${codename} main"
	if [ -f "$REPO_PATH" ] && grep -Fxq "$line" "$REPO_PATH"; then
		echo "Repository already configured in $REPO_PATH"
	else
		echo "$line" | run $SUDO tee "$REPO_PATH" >/dev/null
	fi
}

# Install Terraform package
install_terraform() {
	run $SUDO apt-get update
	if [ -n "$TERRAFORM_VERSION" ]; then
		run $SUDO apt-get install -y "terraform=${TERRAFORM_VERSION}*" || {
			err "Failed to install Terraform ${TERRAFORM_VERSION}. Trying latest available..."
			run $SUDO apt-get install -y terraform
		}
	else
		run $SUDO apt-get install -y terraform
	fi
}

main() {
	echo "Installing HashiCorp Terraform${TERRAFORM_VERSION:+ version $TERRAFORM_VERSION}"

	if [ ! -f "$KEYRING_PATH" ]; then
		fetch_gpg
	else
		echo "Using existing keyring at $KEYRING_PATH"
	fi

	add_repo
	install_terraform

	echo "Terraform installed: $(command -v terraform || true)"
	terraform version || true
}

main "$@"
