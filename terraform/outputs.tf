# ─────────────────────────────────────────────────────────────────────────────
# outputs.tf — Values printed after terraform apply
# ─────────────────────────────────────────────────────────────────────────────

output "ecr_repository_url" {
  description = "Push Docker images to this ECR URL"
  value       = aws_ecr_repository.app.repository_url
}

output "app_security_group_id" {
  description = "ID of the security group attached to ECS tasks"
  value       = aws_security_group.app.id
}

output "ecr_push_commands" {
  description = "Copy-paste commands to authenticate, build, and push the Docker image"
  value       = <<-EOT
    # 1. Authenticate Docker to ECR
    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}

    # 2. Build, tag, and push
    docker build -t ${local.service_name}:${var.container_image_tag} .
    docker tag  ${local.service_name}:${var.container_image_tag} \
                ${aws_ecr_repository.app.repository_url}:${var.container_image_tag}
    docker push ${aws_ecr_repository.app.repository_url}:${var.container_image_tag}
  EOT
}

output "pipeline_artifact_bucket" {
  description = "S3 bucket name — used as ARTIFACT_BUCKET env var in deploy.yml"
  value       = aws_s3_bucket.pipeline_artifacts.bucket
}

output "github_actions_role_arn" {
  description = "Paste into .github/workflows/deploy.yml → role-to-assume"
  value       = aws_iam_role.github_actions.arn
}

