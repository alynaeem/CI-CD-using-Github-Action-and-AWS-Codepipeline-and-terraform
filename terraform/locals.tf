# ─────────────────────────────────────────────────────────────────────────────
# locals.tf — Computed values derived from variables and data sources
# ─────────────────────────────────────────────────────────────────────────────

locals {
  service_name = "product-microservice"
  account_id   = data.aws_caller_identity.current.account_id
  ecr_image    = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.service_name}:${var.container_image_tag}"

  # Confused deputy protection: only ECS tasks in THIS account/region can assume
  # our IAM roles, preventing cross-account privilege escalation attacks.
  ecs_trust_condition = {
    ArnLike      = { "aws:SourceArn"     = "arn:aws:ecs:${var.aws_region}:${local.account_id}:*" }
    StringEquals = { "aws:SourceAccount" = local.account_id }
  }
}
