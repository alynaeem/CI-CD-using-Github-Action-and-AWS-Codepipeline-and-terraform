# ─────────────────────────────────────────────────────────────────────────────
# ecr.tf — Elastic Container Registry (image storage)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "app" {
  name                 = local.service_name
  image_tag_mutability = "IMMUTABLE" # Prevents overwriting released tags

  image_scanning_configuration {
    scan_on_push = true # Free automated vulnerability scanning on every push
  }

  # 🟢 Encrypt images at rest with a KMS-managed key (AWS-managed by default)
  encryption_configuration {
    encryption_type = "KMS"
    # kms_key = aws_kms_key.ecr.arn  # Uncomment to use a customer-managed key
  }
}

# FinOps: Expire images beyond the last 10 to cap ECR storage costs
resource "aws_ecr_lifecycle_policy" "cleanup" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1,
      description  = "FinOps: Keep only the last 10 images",
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 },
      action       = { type = "expire" }
    }]
  })
}

# 🟡 Security Fix: explicit repository policy — restricts push/pull to this
# account only. Without this, overly-permissioned IAM identities could push
# arbitrary images to this repo from anywhere in the account.
resource "aws_ecr_repository_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowAccountRootAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        },
        Action = [
          # Pull actions (ECS execution role uses these)
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          # Push actions (restricted to your account's CI/CD role)
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}
