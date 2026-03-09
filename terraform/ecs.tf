# ─────────────────────────────────────────────────────────────────────────────
# ecs.tf — ECS Cluster, CloudWatch Logs, Task Definition, and Service
# ─────────────────────────────────────────────────────────────────────────────

# ── Cluster ──────────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${local.service_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # Enables per-task CPU/memory metrics in CloudWatch
  }
}

# ── CloudWatch Log Group ──────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "logs" {
  name              = "/ecs/${local.service_name}"
  retention_in_days = 7 # FinOps: minimize log storage costs
}

# ── Task Definition ───────────────────────────────────────────────────────────
# 256 CPU (0.25 vCPU) / 512 MB — right-sized for a lightweight Spring Boot app
resource "aws_ecs_task_definition" "app" {
  family                   = local.service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  # 🔴 Security Fix: explicit task role with zero AWS permissions (zero-trust baseline).
  # The app container currently needs no AWS SDK access. Add policies to
  # aws_iam_role.ecs_task in iam.tf when you add features like S3, Secrets Manager, etc.
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = local.service_name
    image = local.ecr_image

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    # Mirrors the Spring Boot Actuator /health endpoint
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:8080/actuator/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

# ── ECS Service ───────────────────────────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name            = local.service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1

  # FinOps: FARGATE_SPOT is ~70% cheaper than on-demand.
  # Weight-100 Spot + weight-1 on-demand fallback = resilient & cost-efficient.
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
    base              = 0
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1 # Activated only when Spot capacity is exhausted
    base              = 0
  }

  network_configuration {
    subnets          = data.aws_subnets.available.ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true # Set to false when using a VPC with a NAT gateway
  }

  # Prevents Terraform from overriding desired_count on each apply
  # when an autoscaler is actively managing the task count.
  lifecycle {
    ignore_changes = [desired_count]
  }
}
