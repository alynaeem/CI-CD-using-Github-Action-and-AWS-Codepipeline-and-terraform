output "state_bucket_name" {
  description = "Paste into the 'bucket' field of the backend block in /terraform/providers.tf"
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table_name" {
  description = "Paste into the 'dynamodb_table' field of the backend block in /terraform/providers.tf"
  value       = aws_dynamodb_table.tf_lock.name
}

output "backend_config_snippet" {
  description = "Ready-to-paste backend block for /terraform/providers.tf"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.tf_state.bucket}"
      key            = "product-microservice/terraform.tfstate"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.tf_lock.name}"
      encrypt        = true
    }
  EOT
}
