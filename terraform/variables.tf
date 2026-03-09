# ─────────────────────────────────────────────────────────────────────────────
# variables.tf — Input variables with validation
# ─────────────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy into (e.g. us-east-1, eu-west-1)"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^(us|eu)-", var.aws_region))
    error_message = "aws_region must start with 'us-' or 'eu-' (e.g. us-east-1, eu-west-1)."
  }
}

variable "container_image_tag" {
  description = "Docker image tag to deploy. Must be a git SHA (e.g. a1b2c3d) — never 'latest'."
  type        = string
  # No default — forces every deployment to explicitly specify an immutable tag.
}
