output "role_arn" {
  description = "ARN of the IAM role for AWS Secrets & Configuration Provider"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role for AWS Secrets & Configuration Provider"
  value       = aws_iam_role.this.name
}