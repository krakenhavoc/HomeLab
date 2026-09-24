# Backup scripts

No backup script is implemented in this directory yet.

The current documented recovery model is in [Backup and recovery strategy](../../docs/backup-strategy.md). The `cmd_and_ctrl` environments use application-owned restic jobs with Terraform-managed Cloudflare R2 buckets; other backup coverage must be verified on the live Proxmox platform.

Future utilities added here should be service-specific, encrypted, non-interactive, and safe to run more than once. Each must document:

- the exact data source and destination
- credential source and required permissions
- retention owner
- exit codes and monitoring signal
- restore command and verification procedure

A backup script is incomplete until its restore path has been tested.
