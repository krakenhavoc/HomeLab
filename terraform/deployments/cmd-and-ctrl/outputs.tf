output "backup_bucket_name" {
  description = "R2 bucket for off-node backups (cmd_and_ctrl#1031)"
  value       = cloudflare_r2_bucket.backup.name
}

output "backup_s3_endpoint" {
  description = "S3 endpoint for this account's R2 buckets"
  value       = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
}
