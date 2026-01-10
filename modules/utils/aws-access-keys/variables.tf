# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "user_name" {
  type        = string
  description = "Name of the IAM user to create."

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]+$", var.user_name))
    error_message = "user_name must contain only alphanumeric characters and the following: +=,.@_-"
  }
}

variable "policy" {
  type        = any
  description = "IAM policy document as an object. Will be converted to JSON."
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
