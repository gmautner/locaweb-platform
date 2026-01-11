# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "name" {
  type        = string
  description = "Name of the IAM user and role to create."

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]+$", var.name))
    error_message = "name must contain only alphanumeric characters and the following: +=,.@_-"
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
