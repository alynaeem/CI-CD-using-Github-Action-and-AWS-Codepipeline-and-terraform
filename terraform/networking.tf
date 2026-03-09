# ─────────────────────────────────────────────────────────────────────────────
# networking.tf — Security Group for ECS tasks
# ─────────────────────────────────────────────────────────────────────────────

# Fetches the deployer's current public IP at plan time.
# Port 8080 is restricted to exactly this IP — zero open internet exposure.
# Note: if you switch networks between plan and apply, re-run `terraform plan`.
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

resource "aws_security_group" "app" {
  name        = "${local.service_name}-sg"
  description = "Allow inbound HTTP on 8080 (scoped to deployer IP) and unrestricted outbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Spring Boot app port: scoped to current deployer IP only"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  egress {
    description = "All outbound traffic (ECR pull, CloudWatch Logs, RDS, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
