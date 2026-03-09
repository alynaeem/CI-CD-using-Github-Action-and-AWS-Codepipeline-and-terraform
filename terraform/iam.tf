# ─────────────────────────────────────────────────────────────────────────────
# iam.tf — ECS Task Execution Role + Task Role (Least Privilege + Zero Trust)
# ─────────────────────────────────────────────────────────────────────────────



resource "aws_iam_role" "ecs_execution" {
  name = "${local.service_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Condition = local.ecs_trust_condition
    }]
  })
}

# Custom inline policy — scoped to ONLY this service's ECR repo and log group
resource "aws_iam_role_policy" "ecs_execution_inline" {
  name = "${local.service_name}-execution-policy"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        # GetAuthorizationToken is account-level — must remain "*"
        # (AWS does not support resource-level scoping for this action)
        Effect   = "Allow",
        Action   = ["ecr:GetAuthorizationToken"],
        Resource = "*"
      },
      {
        # Image-pull scoped to ONLY this service's ECR repository
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = aws_ecr_repository.app.arn
      },
      {
        # Log writes scoped to ONLY this service's CloudWatch log group.
        # The ":*" suffix targets log streams within the group.
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "${aws_cloudwatch_log_group.logs.arn}:*"
      }
    ]
  })
}

# ── Task Role — used by the application container at runtime ──────────────────
# 🔴 Security Fix: explicitly defined with ZERO policies attached.
# This is intentional: the app currently needs no AWS SDK access.
# Add policies here when you add features (e.g. S3, Secrets Manager, SQS).
# Without this, silently-missing AWS calls in Spring Boot would fail with
# confusing AccessDenied errors and no clear audit trail.
resource "aws_iam_role" "ecs_task" {
  name = "${local.service_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Condition = local.ecs_trust_condition
    }]
  })
}
# No aws_iam_role_policy attached — zero AWS access for the container (by design).
