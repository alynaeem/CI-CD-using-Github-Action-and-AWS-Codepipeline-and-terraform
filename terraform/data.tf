# ─────────────────────────────────────────────────────────────────────────────
# data.tf — Dynamic data lookups (removes hardcoded IDs)
# ─────────────────────────────────────────────────────────────────────────────

# Discovers the default VPC in the configured region automatically
data "aws_vpc" "default" {
  default = true
}

# Discovers all subnets belonging to the default VPC
data "aws_subnets" "available" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Resolves the AWS account ID at plan time — used in locals.tf for ECR image URL
data "aws_caller_identity" "current" {}
