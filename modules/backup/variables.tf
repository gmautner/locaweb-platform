# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  type        = string
  description = "Name of the cluster. Used for S3 bucket and IAM resources naming."
}
