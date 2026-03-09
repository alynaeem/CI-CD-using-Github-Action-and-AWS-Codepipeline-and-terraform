# ─────────────────────────────────────────────────────────────────────────────
# cicd.tf — GitHub Actions OIDC Authentication & Deploy Role
#
# Allows GitHub Actions to assume an AWS role using short-lived OIDC tokens.
# No static AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY ever stored in GitHub.
# ─────────────────────────────────────────────────────────────────────────────

# GitHub's OIDC provider — registered once per AWS account.
# If it already exists, import it:
#   terraform import aws_iam_openid_connect_provider.github \
#     arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ── GitHub Actions Deploy Role ────────────────────────────────────────────────
resource "aws_iam_role" "github_actions" {
  name = "${local.service_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          # Restrict to pushes on main branch of this specific repo only
          "token.actions.githubusercontent.com:sub" = "repo:alynaeem/CI-CD-using-Github-Action-and-AWS-Codepipeline-and-terraform:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_inline" {
  name = "${local.service_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        # Required for `docker login` — account-level, cannot be scoped further
        Sid      = "ECRAuth",
        Effect   = "Allow",
        Action   = ["ecr:GetAuthorizationToken"],
        Resource = "*"
      },
      {
        # Docker image push — scoped to ONLY this service's ECR repository
        Sid    = "ECRPush",
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        Resource = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${local.service_name}"
      },
      {
        # Upload imagedefinitions.json to trigger CodePipeline via S3
        # Scoped to ONLY the pipeline artifact bucket
        Sid    = "S3ArtifactUpload",
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetBucketVersioning"
        ],
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      },
      {
        # Task definition + ECS PassRole — not needed for CI-only role
        # but kept here in case manual deploy override is needed
        Sid    = "ECSTaskDef",
        Effect = "Allow",
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition"
        ],
        Resource = "*"
      },
      {
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
