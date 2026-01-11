# =============================================================================
# OUTPUTS
# =============================================================================

output "access_key_id" {
  description = "The access key ID."
  value       = aws_iam_access_key.this.id
}

output "secret_access_key" {
  description = "The secret access key."
  value       = aws_iam_access_key.this.secret
  sensitive   = true
}

output "user_name" {
  description = "The name of the IAM user."
  value       = aws_iam_user.this.name
}

output "user_arn" {
  description = "The ARN of the IAM user."
  value       = aws_iam_user.this.arn
}

output "role_name" {
  description = "The name of the IAM role."
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "The ARN of the IAM role."
  value       = aws_iam_role.this.arn
}

output "policy_arn" {
  description = "The ARN of the IAM policy."
  value       = aws_iam_policy.this.arn
}
