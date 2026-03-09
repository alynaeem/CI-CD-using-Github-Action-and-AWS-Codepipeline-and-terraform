# Product Microservice — DevOps Portfolio Project

A production-ready Java microservice with a FinOps-optimised AWS deployment pipeline, demonstrating:

- **Spring Boot 3** REST API (Product CRUD) with Lombok, MapStruct, and Bean Validation
- **Multi-stage Docker build** (<200 MB image) with non-root user and container-aware JVM flags
- **Spring Boot Actuator** exposing `/health`, `/metrics`, `/info`, `/prometheus`
- **Modular Terraform** infrastructure with blast radius isolation
- **FinOps**: ECS Fargate Spot (~70% cheaper), PAY_PER_REQUEST DynamoDB, 7-day CloudWatch retention
- **Security**: Least-privilege IAM, confused deputy protection, KMS ECR encryption, dynamic IP-scoped Security Group

---

## Repository Structure

```
store/
├── bootstrap/          ← Step 1: State management infrastructure (run once)
│   ├── main.tf         S3 bucket + DynamoDB table for remote state
│   └── outputs.tf      Prints backend config snippet for Step 2
│
├── terraform/          ← Step 3: Application infrastructure
│   ├── providers.tf    AWS provider + S3 backend (activate after Step 2)
│   ├── ecr.tf          ECR repository with KMS encryption + lifecycle policy
│   ├── iam.tf          ECS execution + task roles (least privilege)
│   ├── networking.tf   Security group (port 8080, scoped to your current IP)
│   ├── ecs.tf          Cluster, task definition, Fargate Spot service
│   └── outputs.tf      ECR URL + push commands
│
├── src/                Spring Boot application source
├── Dockerfile          Multi-stage build: Maven builder → Alpine JRE runtime
├── docker-compose.yml  Local dev: app + postgres:15-alpine with healthcheck
└── pom.xml
```

---

## Deployment Order

### Step 1 — Bootstrap State Infrastructure (once only)

```bash
cd bootstrap
terraform init
terraform apply
# Copy the `backend_config_snippet` from the output
```

### Step 2 — Activate Remote Backend

Open `terraform/providers.tf` and uncomment the `backend "s3"` block.  
Paste in the values from the Step 1 output (bucket name includes your account ID).

```hcl
backend "s3" {
  bucket         = "product-microservice-tf-state-<account-id>"
  key            = "product-microservice/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "product-microservice-tf-lock"
  encrypt        = true
}
```

### Step 3 — Deploy Application Infrastructure

```bash
cd terraform
terraform init          # Terraform asks to migrate local → S3 state. Answer: yes
terraform plan
terraform apply -var="container_image_tag=<git-sha>"
```

Build and push the Docker image using the `ecr_push_commands` output.

---

## Local Development

```bash
# H2 in-memory (no Docker needed)
mvn spring-boot:run
curl http://localhost:8080/actuator/health
curl http://localhost:8080/api/v1/products

# Full stack with PostgreSQL
docker compose up --build -d
```

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| `bootstrap/` at project root | Blast radius isolation — `terraform destroy` in `terraform/` cannot touch state infra |
| `force_destroy = false` on S3 | AWS refuses to delete non-empty state bucket — two-layer protection |
| `prevent_destroy = true` on S3 + DynamoDB | Terraform blocks destroy before AWS even gets the API call |
| Fargate Spot at weight=100 | ~70% cost saving; on-demand fallback at weight=1 for resilience |
| Dynamic IP in Security Group | Port 8080 scoped to the deployer's current IP — zero open internet access |
| Scoped IAM statements (3 separate) | True least privilege: ECR repo ARN, log group ARN, account-level only where required |
