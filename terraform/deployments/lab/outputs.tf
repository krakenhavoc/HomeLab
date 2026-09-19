output "cmd_and_ctrl_backup_bucket_names" {
  description = <<-EOT
    R2 bucket name for cmd_and_ctrl off-node backups, per environment (prod,
    dev). The owner copies these into cmd_and_ctrl's per-environment backup
    secrets (cmd_and_ctrl#1031).
  EOT
  value       = { for env, bucket in cloudflare_r2_bucket.cmd_and_ctrl_backup : env => bucket.name }
}

output "cmd_and_ctrl_backup_s3_endpoint" {
  description = <<-EOT
    S3-compatible endpoint for this Cloudflare account's R2 buckets. The same
    endpoint serves every bucket in the account; only the bucket name and the
    per-bucket API token differ. The owner copies this into cmd_and_ctrl's
    backup secrets alongside the bucket name (cmd_and_ctrl#1031).
  EOT
  value       = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
}
