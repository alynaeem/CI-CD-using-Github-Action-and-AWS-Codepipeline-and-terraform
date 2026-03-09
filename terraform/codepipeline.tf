# ─────────────────────────────────────────────────────────────────────────────
# codepipeline.tf — AWS CodePipeline CD Stage
#
# Watches for imagedefinitions.json uploaded to S3 by GitHub Actions,
# then deploys to ECS using the standard ECS deploy action.
#
# No existing resources are modified. Uses data sources to reference
# the existing ECR repo and ECS cluster/service by name.
# ─────────────────────────────────────────────────────────────────────────────

# ── Reference existing resources via data sources ─────────────────────────────
data "aws_ecr_repository" "pipeline_app" {
  name = local.service_name
}

data "aws_ecs_cluster" "pipeline_app" {
  cluster_name = "${local.service_name}-cluster"
}

# ── S3 Artifact Bucket ────────────────────────────────────────────────────────
# Stores imagedefinitions.json uploaded by GitHub Actions.
# Object versioning enables EventBridge to detect each new upload as a change.
resource "aws_s3_bucket" "pipeline_artifacts" {
  # Bucket name includes account ID to guarantee global uniqueness
  bucket = "${local.service_name}-pipeline-${local.account_id}"

  # Prevent accidental deletion — pipeline history lives here
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Purpose   = "codepipeline-artifacts"
    Project   = local.service_name
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  versioning_configuration {
    status = "Enabled" # Required: CodePipeline S3 source needs versioned objects
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket                  = aws_s3_bucket.pipeline_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── CodePipeline IAM Service Role ─────────────────────────────────────────────
resource "aws_iam_role" "codepipeline" {
  name = "${local.service_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "codepipeline.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_inline" {
  name = "${local.service_name}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        # Read/write the artifact bucket for pipeline input/output
        Sid    = "ArtifactBucket",
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ],
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      },
      {
        # ECR permissions — scoped to this service's repository
        Sid    = "ECRAccess",
        Effect = "Allow",
        Action = [
          "ecr:DescribeImages",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ],
        Resource = data.aws_ecr_repository.pipeline_app.arn
      },
      {
        # GetAuthorizationToken is account-level — cannot be scoped
        Sid      = "ECRAuth",
        Effect   = "Allow",
        Action   = ["ecr:GetAuthorizationToken"],
        Resource = "*"
      },
      {
        # ECS deploy — scoped to this specific service
        Sid    = "ECSUpdate",
        Effect = "Allow",
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ],
        Resource = "arn:aws:ecs:${var.aws_region}:${local.account_id}:service/${local.service_name}-cluster/${local.service_name}"
      },
      {
        # Required to register new task definition revisions during deploy
        Sid    = "ECSTaskDef",
        Effect = "Allow",
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition"
        ],
        Resource = "*"
      },
      {
        # CodePipeline must pass the ECS execution + task roles to ECS
        Sid    = "PassECSRoles",
        Effect = "Allow",
        Action = ["iam:PassRole"],
        Resource = [
          aws_iam_role.ecs_execution.arn,
          aws_iam_role.ecs_task.arn
        ]
      }
    ]
  })
}

# ── CodePipeline ──────────────────────────────────────────────────────────────
resource "aws_codepipeline" "app" {
  name     = "${local.service_name}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # ── Stage 1: Source ─────────────────────────────────────────────────────
  # Watches for imagedefinitions.json uploaded by GitHub Actions CI.
  # EventBridge detects each new object version — triggers within seconds.
  stage {
    name = "Source"

    action {
      name             = "S3-Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceOutput"]

      configuration = {
        S3Bucket             = aws_s3_bucket.pipeline_artifacts.bucket
        S3ObjectKey          = "imagedefinitions.json"
        PollForSourceChanges = "false" # Use EventBridge instead of polling
      }
    }
  }

  # ── Stage 2: Deploy ─────────────────────────────────────────────────────
  # ECS standard deploy — reads imagedefinitions.json from the source artifact
  # and performs a rolling update on the existing ECS service.
  stage {
    name = "Deploy"

    action {
      name            = "ECS-Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["SourceOutput"]

      configuration = {
        ClusterName = data.aws_ecs_cluster.pipeline_app.cluster_name
        ServiceName = local.service_name
        FileName    = "imagedefinitions.json"
        # DeploymentTimeout = "15"  # minutes — uncomment to override the 60-min default
      }
    }
  }
}

# ── EventBridge Rule — S3 upload triggers the pipeline ────────────────────────
# Without this, the pipeline would need PollForSourceChanges=true (less efficient).
resource "aws_cloudwatch_event_rule" "pipeline_trigger" {
  name        = "${local.service_name}-pipeline-trigger"
  description = "Triggers CodePipeline when GHA uploads a new imagedefinitions.json to S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"],
    detail-type = ["Object Created"],
    detail = {
      bucket = { name = [aws_s3_bucket.pipeline_artifacts.bucket] },
      object = { key = ["imagedefinitions.json"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "pipeline_trigger" {
  rule     = aws_cloudwatch_event_rule.pipeline_trigger.name
  arn      = aws_codepipeline.app.arn
  role_arn = aws_iam_role.eventbridge_pipeline.arn
}

# EventBridge needs its own role to start the pipeline
resource "aws_iam_role" "eventbridge_pipeline" {
  name = "${local.service_name}-eventbridge-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "events.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_pipeline" {
  name = "${local.service_name}-eventbridge-pipeline-policy"
  role = aws_iam_role.eventbridge_pipeline.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["codepipeline:StartPipelineExecution"],
      Resource = aws_codepipeline.app.arn
    }]
  })
}

# Also enable EventBridge notifications on the S3 bucket
resource "aws_s3_bucket_notification" "pipeline_artifacts" {
  bucket      = aws_s3_bucket.pipeline_artifacts.id
  eventbridge = true # Sends all S3 events to EventBridge (default event bus)
}
