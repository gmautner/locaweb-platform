# =============================================================================
# AWS IAM BUNDLE: USER + ROLE WITH POLICY-BOUND ACCESS KEYS
# =============================================================================

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# IAM User
# -----------------------------------------------------------------------------

resource "aws_iam_user" "this" {
  name = var.name
  tags = var.tags
}

# -----------------------------------------------------------------------------
# IAM Policy
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "this" {
  name   = var.name
  policy = jsonencode(var.policy)
  tags   = var.tags
}

# -----------------------------------------------------------------------------
# IAM Role (trusts the user)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "this" {
  name = var.name
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.this.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Policy Attachment (to role, not user)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

# -----------------------------------------------------------------------------
# Access Keys
# -----------------------------------------------------------------------------

resource "aws_iam_access_key" "this" {
  user = aws_iam_user.this.name
}
