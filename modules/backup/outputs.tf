# =============================================================================
# OUTPUTS
# =============================================================================

output "bucket_name" {
  description = "The name of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "access_key_id" {
  description = "The access key ID."
  value       = aws_iam_access_key.this.id
}

output "secret_access_key" {
  description = "The secret access key."
  value       = aws_iam_access_key.this.secret
  sensitive   = true
}

output "user_arn" {
  description = "The ARN of the IAM user."
  value       = aws_iam_user.this.arn
}

output "role_arn" {
  description = "The ARN of the IAM role."
  value       = aws_iam_role.this.arn
}
