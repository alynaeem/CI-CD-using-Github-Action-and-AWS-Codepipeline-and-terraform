# ─────────────────────────────────────────────────────────────────────────────
# providers.tf — Terraform core config & AWS provider
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5"

  backend "s3" {
    bucket         = "product-microservice-tf-state-345657619384"
    key            = "product-microservice/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "product-microservice-tf-lock"
    encrypt        = true
  }

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
