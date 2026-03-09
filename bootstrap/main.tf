# ─────────────────────────────────────────────────────────────────────────────
# bootstrap/main.tf — Terraform State Infrastructure
#
# PURPOSE: Creates the S3 bucket and DynamoDB table for remote state management.
#          This folder uses LOCAL state and is run ONCE before /terraform.
#
# ⚠️  NEVER run `terraform destroy` in this folder.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5"
  # Intentionally NO backend block — this folder manages the state bucket itself.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region — must match the region used in /terraform"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project identifier used to name the bucket and lock table"
  type        = string
  default     = "product-microservice"
}

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  # Account ID suffix guarantees global bucket name uniqueness
  bucket_name = "${var.project_name}-tf-state-${local.account_id}"
  table_name  = "${var.project_name}-tf-lock"
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 Bucket — Terraform State Storage
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "tf_state" {
  bucket = local.bucket_name

  # AWS-level guard: refuses bucket deletion if it still contains state objects.
  # You must manually empty the bucket before AWS will allow deletion.
  force_destroy = false

  # Terraform-level guard: blocks `terraform destroy` from even attempting deletion.
  # Must be manually set to false and re-applied before destroy can proceed —
  # an intentional two-step friction that prevents accidental destruction.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Purpose   = "terraform-state"
    Project   = var.project_name
    ManagedBy = "terraform-bootstrap"
  }
}

# Every state write is stored as a versioned object — enables rollback
# if a bad apply corrupts the state file.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# AES256 encryption at rest — state files can contain sensitive ARNs and IPs
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Hard block on all public access — state files must never be public
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────────────────────────────────────
# DynamoDB Table — State Locking
# Prevents concurrent `terraform apply` runs from corrupting the state file.
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_dynamodb_table" "tf_lock" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST" # FinOps: zero idle cost

  hash_key = "LockID" # Required attribute name for Terraform state locking

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Purpose   = "terraform-state-lock"
    Project   = var.project_name
    ManagedBy = "terraform-bootstrap"
  }
}
